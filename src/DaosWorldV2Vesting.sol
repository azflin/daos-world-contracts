// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {DaosWorldV1Token} from "./DaosWorldV1Token.sol";

import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";

import {INonfungiblePositionManager, IUniswapV3Factory, ISwapRouter02} from "./interfaces/IUniswap.sol";
import {ILockerFactory, ILocker} from "./interfaces/ILocker.sol";
import {DaosWorldPayFactory} from "./vesting/DaosWorldPayFactory.sol";
import {DaosWorldPay} from "./vesting/DaosWorldPay.sol";

contract DaosWorldV2Vesting is Ownable, ReentrancyGuard {
    using SafeERC20 for ERC20;
    using TickMath for int24;

    uint24 public constant UNI_V3_FEE = 10000;
    uint256 public constant SUPPLY_TO_LP = 100_000_000 ether;
    uint256 public constant SUPPLY_TO_FUNDRAISERS = 1_000_000_000 * 1e18;
    IUniswapV3Factory public constant UNISWAP_V3_FACTORY = IUniswapV3Factory(0x33128a8fC17869897dcE68Ed026d694621f6FDfD);
    INonfungiblePositionManager public constant POSITION_MANAGER =
        INonfungiblePositionManager(0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1);
    address public constant WETH = 0x4200000000000000000000000000000000000006;
    ISwapRouter02 public constant SWAP_ROUTER_02 = ISwapRouter02(0x2626664c2603336E57B271c5C0b26F421741e481);
    ILockerFactory public liquidityLockerFactory;
    address public liquidityLocker;

    uint256 public totalRaised;
    uint256 public fundraisingGoal;
    bool public fundraisingFinalized;
    bool public goalReached;
    uint256 public fundraisingDeadline;
    uint256 public fundExpiry;
    uint8 public lpFeesCut = 60;
    address public protocolAdmin;
    string public name;
    string public symbol;
    address public daoToken;

    // If maxWhitelistAmount > 0, then its whitelist only. And this is the max amount you can contribute.
    uint256 public maxWhitelistAmount;
    // If maxPublicContributionAmount > 0, then you cannot contribute more than this in public rounds.
    uint256 public maxPublicContributionAmount;

    // The amount of ETH you've contributed
    mapping(address => uint256) public contributions;
    mapping(address => bool) public whitelist;
    address[] public whitelistArray;
    address[] public contributors;

    uint256 public initialVestPercent;
    uint256 public vestingStartTime;
    uint256 public vestingEndTime;

    DaosWorldPayFactory public immutable daosWorldPayFactory;
    DaosWorldPay public daosWorldPay;

    event Contribution(address indexed contributor, uint256 amount);
    event FundraisingFinalized(address token, address pool, address daosWorldPay, uint256 tokenId);
    event Refund(address indexed contributor, uint256 amount);
    event AddWhitelist(address);
    event RemoveWhitelist(address);
    event Claim(address indexed contributor, uint256 amount);

    struct Config {
        uint256 _fundraisingGoal;
        string _name;
        string _symbol;
        uint256 _fundraisingDeadline;
        uint256 _fundExpiry;
        address _daoManager;
        address _liquidityLockerFactory;
        uint256 _maxWhitelistAmount;
        address _protocolAdmin;
        uint256 _maxPublicContributionAmount;
        address _daosWorldPayFactory;
    }

    constructor(Config memory _config) Ownable(_config._daoManager) {
        require(_config._fundraisingGoal > 0, "Fundraising goal must be greater than 0");
        require(_config._fundraisingDeadline > block.timestamp, "_fundraisingDeadline > block.timestamp");
        require(_config._fundExpiry > _config._fundraisingDeadline, "_fundExpiry > fundraisingDeadline");
        name = _config._name;
        symbol = _config._symbol;
        fundraisingGoal = _config._fundraisingGoal;
        fundraisingDeadline = _config._fundraisingDeadline;
        fundExpiry = _config._fundExpiry;
        liquidityLockerFactory = ILockerFactory(_config._liquidityLockerFactory);
        maxWhitelistAmount = _config._maxWhitelistAmount;
        protocolAdmin = _config._protocolAdmin;
        maxPublicContributionAmount = _config._maxPublicContributionAmount;
        daosWorldPayFactory = DaosWorldPayFactory(_config._daosWorldPayFactory);
    }

    function contribute() public payable nonReentrant {
        require(!goalReached, "Goal already reached");
        require(block.timestamp < fundraisingDeadline, "Deadline hit");
        require(msg.value > 0, "Contribution must be greater than 0");
        if (maxWhitelistAmount > 0) {
            require(whitelist[msg.sender], "You are not whitelisted");
            require(contributions[msg.sender] + msg.value <= maxWhitelistAmount, "Exceeding maxWhitelistAmount");
        } else if (maxPublicContributionAmount > 0) {
            require(
                contributions[msg.sender] + msg.value <= maxPublicContributionAmount,
                "Exceeding maxPublicContributionAmount"
            );
        }

        uint256 effectiveContribution = msg.value;
        if (totalRaised + msg.value > fundraisingGoal) {
            effectiveContribution = fundraisingGoal - totalRaised;
            payable(msg.sender).transfer(msg.value - effectiveContribution);
        }

        if (contributions[msg.sender] == 0) {
            contributors.push(msg.sender);
        }

        contributions[msg.sender] += effectiveContribution;
        totalRaised += effectiveContribution;

        emit Contribution(msg.sender, effectiveContribution);

        if (totalRaised == fundraisingGoal) {
            goalReached = true;
        }
    }

    function addToWhitelist(address[] calldata addresses) external {
        require(msg.sender == owner() || msg.sender == protocolAdmin, "Must be owner or protocolAdmin");
        for (uint256 i = 0; i < addresses.length; i++) {
            if (!whitelist[addresses[i]]) {
                whitelist[addresses[i]] = true;
                whitelistArray.push(addresses[i]);
                emit AddWhitelist(addresses[i]);
            }
        }
    }

    function getWhitelistLength() public view returns (uint256) {
        return whitelistArray.length;
    }

    function removeFromWhitelist(address removedAddress) external {
        require(msg.sender == owner() || msg.sender == protocolAdmin, "Must be owner or protocolAdmin");
        whitelist[removedAddress] = false;

        for (uint256 i = 0; i < whitelistArray.length; i++) {
            if (whitelistArray[i] == removedAddress) {
                whitelistArray[i] = whitelistArray[whitelistArray.length - 1];
                whitelistArray.pop();
                break;
            }
        }

        emit RemoveWhitelist(removedAddress);
    }

    function setMaxWhitelistAmount(uint256 _maxWhitelistAmount) public {
        require(msg.sender == owner() || msg.sender == protocolAdmin, "Must be owner or protocolAdmin");
        maxWhitelistAmount = _maxWhitelistAmount;
    }

    function setMaxPublicContributionAmount(uint256 _maxPublicContributionAmount) public {
        require(msg.sender == owner() || msg.sender == protocolAdmin, "Must be owner or protocolAdmin");
        maxPublicContributionAmount = _maxPublicContributionAmount;
    }

    // Finalize the fundraising and distribute tokens
    function finalizeFundraising(
        int24 initialTick,
        int24 upperTick,
        bytes32 salt,
        uint256 snipeAmount,
        uint256 _initialVestPercent,
        uint256 _vestingDuration
    ) external onlyOwner {
        require(goalReached, "Fundraising goal not reached");
        require(!fundraisingFinalized, "DAO tokens already minted");
        require(_initialVestPercent <= 100, "Initial vest must be <= 100");

        initialVestPercent = _initialVestPercent;
        vestingStartTime = block.timestamp;
        vestingEndTime = block.timestamp + _vestingDuration;

        DaosWorldV1Token token = new DaosWorldV1Token{salt: salt}(name, symbol);
        daoToken = address(token);
        require(address(token) < WETH, "Invalid salt");

        daosWorldPay = DaosWorldPay(daosWorldPayFactory.createDaosWorldPayContract(address(token)));

        uint256 decimalsDiv = daosWorldPay.DECIMALS_DIVISOR();
        uint256 contribLength = contributors.length;

        token.mint(address(this), SUPPLY_TO_FUNDRAISERS);
        token.approve(address(daosWorldPay), SUPPLY_TO_FUNDRAISERS);

        uint256 totalTokensNeeded = 0;
        for (uint256 i; i < contribLength;) {
            address contributor = contributors[i];
            uint256 tokensToMint = (contributions[contributor] * SUPPLY_TO_FUNDRAISERS) / totalRaised;

            uint256 initialTokens = (tokensToMint * initialVestPercent) / 100;
            uint256 vestingTokens = tokensToMint - initialTokens;

            // Handle initial tokens first (unconditional)
            if (initialTokens > 0) {
                token.transfer(contributor, initialTokens);
            }

            // Handle vesting tokens separately
            if (vestingTokens > 0) {
                uint216 amountPerSec;
                unchecked {
                    amountPerSec = uint216((vestingTokens * decimalsDiv) / _vestingDuration);
                }
                totalTokensNeeded += vestingTokens;

                daosWorldPay.createStream(contributor, amountPerSec);
            }

            unchecked {
                ++i;
            }
        }
        daosWorldPay.deposit(totalTokensNeeded);

        fundraisingFinalized = true;

        // setup the uniswap v3 pool
        uint160 sqrtPriceX96 = initialTick.getSqrtRatioAtTick();
        address pool = UNISWAP_V3_FACTORY.createPool(address(token), WETH, UNI_V3_FEE);
        IUniswapV3Factory(pool).initialize(sqrtPriceX96);

        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams(
            address(token),
            WETH,
            UNI_V3_FEE,
            initialTick,
            upperTick,
            SUPPLY_TO_LP,
            0,
            0,
            0,
            address(this),
            block.timestamp
        );

        // mint 100M more tokens for LP
        token.mint(address(this), SUPPLY_TO_LP);
        // transfer ownership to 0 address so no more tokens can be minted
        token.renounceOwnership();

        token.approve(address(POSITION_MANAGER), SUPPLY_TO_LP);
        (uint256 tokenId,,,) = POSITION_MANAGER.mint(params);

        SWAP_ROUTER_02.exactInputSingle{value: snipeAmount}(
            ISwapRouter02.ExactInputSingleParams({
                tokenIn: WETH,
                tokenOut: address(token),
                fee: UNI_V3_FEE,
                recipient: address(this),
                amountIn: snipeAmount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );

        address lockerAddress = liquidityLockerFactory.deploy(
            address(POSITION_MANAGER), owner(), uint64(fundExpiry), tokenId, lpFeesCut, address(this)
        );

        POSITION_MANAGER.safeTransferFrom(address(this), lockerAddress, tokenId);

        ILocker(lockerAddress).initializer(tokenId);
        liquidityLocker = lockerAddress;

        emit FundraisingFinalized(address(token), address(pool), address(daosWorldPay), tokenId);
    }

    // Allow contributors to get a refund if the goal is not reached
    function refund() external nonReentrant {
        require(!goalReached, "Fundraising goal was reached");
        require(block.timestamp > fundraisingDeadline, "Deadline not reached yet");
        require(contributions[msg.sender] > 0, "No contributions to refund");

        uint256 contributedAmount = contributions[msg.sender];
        contributions[msg.sender] = 0;

        payable(msg.sender).transfer(contributedAmount);

        emit Refund(msg.sender, contributedAmount);
    }

    // This function is for the DAO manager to trade
    function execute(address[] calldata contracts, bytes[] calldata data, uint256[] calldata msgValues)
        external
        onlyOwner
    {
        require(fundraisingFinalized, "Fundraising not finalized");
        require(contracts.length == data.length && data.length == msgValues.length, "Array lengths mismatch");

        for (uint256 i = 0; i < contracts.length; i++) {
            (bool success,) = contracts[i].call{value: msgValues[i]}(data[i]);
            require(success, "Call failed");
        }
    }

    function extendFundExpiry(uint256 newFundExpiry) external onlyOwner {
        require(newFundExpiry > fundExpiry, "Must choose later fund expiry");
        fundExpiry = newFundExpiry;
        ILocker(liquidityLocker).extendFundExpiry(newFundExpiry);
    }

    function extendFundraisingDeadline(uint256 newFundraisingDeadline) external {
        require(msg.sender == owner() || msg.sender == protocolAdmin, "Must be owner or protocolAdmin");
        require(!goalReached, "Fundraising goal was reached");
        require(newFundraisingDeadline > fundraisingDeadline, "new fundraising deadline must be > old one");
        fundraisingDeadline = newFundraisingDeadline;
    }

    function emergencyEscape() external {
        require(msg.sender == protocolAdmin, "must be protocol admin");
        require(!fundraisingFinalized, "fundraising already finalized");
        (bool success,) = protocolAdmin.call{value: address(this).balance}("");
        require(success, "Transfer failed");
    }

    // Fallback function to make contributions simply by sending ETH to the contract
    receive() external payable {
        if (!goalReached && block.timestamp < fundraisingDeadline) {
            contribute();
        }
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
