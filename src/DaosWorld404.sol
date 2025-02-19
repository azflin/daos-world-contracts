// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";

import {INonfungiblePositionManager, IUniswapV3Factory, ISwapRouter02} from "./interfaces/IUniswap.sol";
import {ILockerFactory, ILocker} from "./interfaces/ILocker.sol";

import {DaosWorld404Token, TokenDistributionLib} from "./lib/TokenDistributionLib.sol";

contract DaosWorld404 is Ownable, ReentrancyGuard {
    using SafeERC20 for ERC20;
    using TickMath for int24;

    uint24 public constant UNI_V3_FEE = 10000;
    uint256 public supplyToLp;
    uint256 public supplyToFundraisers;

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
    bool public constant IS_404 = true;

    // If maxWhitelistAmount > 0, then its whitelist only. And this is the max amount you can contribute.
    uint256 public maxWhitelistAmount;
    // If maxPublicContributionAmount > 0, then you cannot contribute more than this in public rounds.
    uint256 public maxPublicContributionAmount;

    // The amount of ETH you've contributed
    mapping(address => uint256) public contributions;
    mapping(address => bool) public whitelist;
    address[] public whitelistArray;
    address[] public contributors;

    event Contribution(address indexed contributor, uint256 amount);
    event FundraisingFinalized(address token, address pool, uint256 tokenId);
    event Refund(address indexed contributor, uint256 amount);
    event AddWhitelist(address);
    event RemoveWhitelist(address);

    constructor(
        uint256 _fundraisingGoal,
        string memory _name,
        string memory _symbol,
        uint256 _fundraisingDeadline,
        uint256 _fundExpiry,
        address _daoManager,
        address _liquidityLockerFactory,
        uint256 _maxWhitelistAmount,
        address _protocolAdmin,
        uint256 _maxPublicContributionAmount
    ) Ownable(_daoManager) {
        require(_fundraisingGoal > 0, "Fundraising goal must be greater than 0");
        require(_fundraisingDeadline > block.timestamp, "_fundraisingDeadline > block.timestamp");
        require(_fundExpiry > fundraisingDeadline, "_fundExpiry > fundraisingDeadline");
        name = _name;
        symbol = _symbol;
        fundraisingGoal = _fundraisingGoal;
        fundraisingDeadline = _fundraisingDeadline;
        fundExpiry = _fundExpiry;
        liquidityLockerFactory = ILockerFactory(_liquidityLockerFactory);
        maxWhitelistAmount = _maxWhitelistAmount;
        protocolAdmin = _protocolAdmin;
        maxPublicContributionAmount = _maxPublicContributionAmount;
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
        string calldata _nftUrl,
        bytes32 salt,
        uint256 snipeAmount,
        uint256 maxNftSupply
    ) external onlyOwner {
        require(goalReached, "Fundraising goal not reached");
        require(!fundraisingFinalized, "DAO tokens already minted");

        // Calculate token supplies based on maxNftSupply
        supplyToLp = (maxNftSupply * 1e18) / 10; // 10% to LP
        supplyToFundraisers = (maxNftSupply * 1e18) - supplyToLp; // Remaining to fundraisers

        DaosWorld404Token token =
            TokenDistributionLib.deployToken(name, symbol, _nftUrl, maxNftSupply, address(this), owner(), salt);
        daoToken = address(token);
        require(address(token) < WETH, "Invalid salt");

        // Transfer tokens to contributors from the total supply
        for (uint256 i = 0; i < contributors.length; i++) {
            address contributor = contributors[i];
            uint256 contribution = contributions[contributor];
            uint256 tokensToTransfer = (contribution * supplyToFundraisers) / totalRaised;

            // Transfer ERC20 tokens to contributor
            token.transfer(contributor, tokensToTransfer);
        }

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
            token.balanceOf(address(this)), // Use remaining LP tokens
            0,
            0,
            0,
            address(this),
            block.timestamp
        );

        // No need to mint more tokens - we already have SUPPLY_TO_LP tokens remaining
        token.approve(address(POSITION_MANAGER), supplyToLp);
        (uint256 tokenId,,,) = POSITION_MANAGER.mint(params);

        // transfer ownership to 0 address so no more tokens can be minted
        token.renounceOwnership();

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
        emit FundraisingFinalized(address(token), pool, tokenId);
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
        require(fundraisingFinalized);
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
