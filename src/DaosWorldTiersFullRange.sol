// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {DaosWorldV1Token} from "./DaosWorldV1Token.sol";
import {DaosWorldClaim} from "./DaosWorldClaim.sol";

import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";

import {INonfungiblePositionManager, IUniswapV3Factory, ISwapRouter02} from "./interfaces/IUniswap.sol";
import {ILockerFactory, ILocker} from "./interfaces/ILocker.sol";

contract DaosWorldTiersFullRange is Ownable, ReentrancyGuard {
    using SafeERC20 for ERC20;
    using TickMath for int24;

    uint24 public constant UNI_V3_FEE = 10000;
    uint256 public supplyToLp;
    uint256 public supplyToFundraisers;
    uint256 public constant MAX_SUPPLY = 1_000_000_000 ether;
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
    uint256 public tierDivisor = 1;
    uint256 public minContributionAmount;
    uint256 public totalAdjustedContributions;
    address public daosWorldClaim;

    // If maxWhitelistAmount > 0, then its whitelist only. And this is the max amount you can contribute.
    uint256 public maxWhitelistAmount;
    // If maxPublicContributionAmount > 0, then you cannot contribute more than this in public rounds.
    uint256 public maxPublicContributionAmount;

    struct ContributionAmount {
        uint256 amount;
        uint256 index;
    }
    // The amount of ETH you've contributed

    mapping(address => ContributionAmount) public contributions;
    mapping(address => bool) public whitelist;
    address[] public whitelistArray;
    mapping(address => bool) public claimed;

    struct Contributor {
        address addr;
        uint256 tierDivisor;
    }

    Contributor[] public contributors;

    event Contribution(address indexed contributor, uint256 amount);
    event FundraisingFinalized(address token, address pool, uint256 tokenId);
    event Refund(address indexed contributor, uint256 amount);
    event AddWhitelist(address);
    event RemoveWhitelist(address);
    event TierSet(uint256 newTier);
    event MinContributionAmountSet(uint256 amount);

    struct DaoConfig {
        // Basic DAO info
        string name;
        string symbol;
        address daoManager;
        address protocolAdmin;
        // Fundraising parameters
        uint256 fundraisingGoal;
        uint256 fundraisingDeadline;
        uint256 fundExpiry;
        // Contribution limits
        uint256 maxWhitelistAmount;
        uint256 maxPublicContributionAmount;
        uint256 minContributionAmount;
        // External contracts
        address liquidityLockerFactory;
    }

    constructor(DaoConfig memory config) Ownable(config.daoManager) {
        require(config.fundraisingGoal > 0, "Fundraising goal must be greater than 0");
        require(config.fundraisingDeadline > block.timestamp, "_fundraisingDeadline > block.timestamp");
        require(config.fundExpiry > config.fundraisingDeadline, "_fundExpiry > fundraisingDeadline");

        name = config.name;
        symbol = config.symbol;
        protocolAdmin = config.protocolAdmin;
        fundraisingGoal = config.fundraisingGoal;
        fundraisingDeadline = config.fundraisingDeadline;
        fundExpiry = config.fundExpiry;
        maxWhitelistAmount = config.maxWhitelistAmount;
        maxPublicContributionAmount = config.maxPublicContributionAmount;
        minContributionAmount = config.minContributionAmount;
        liquidityLockerFactory = ILockerFactory(config.liquidityLockerFactory);
    }

    function contribute() public payable nonReentrant {
        require(!goalReached, "Goal already reached");
        require(block.timestamp < fundraisingDeadline, "Deadline hit");
        require(msg.value >= minContributionAmount, "Below minimum contribution");
        require(msg.value > 0, "Contribution must be greater than 0");

        if (maxWhitelistAmount > 0) {
            require(whitelist[msg.sender], "You are not whitelisted");
            require(contributions[msg.sender].amount + msg.value <= maxWhitelistAmount, "Exceeding maxWhitelistAmount");
        } else if (maxPublicContributionAmount > 0) {
            require(
                contributions[msg.sender].amount + msg.value <= maxPublicContributionAmount,
                "Exceeding maxPublicContributionAmount"
            );
        }

        uint256 effectiveContribution = msg.value;
        if (totalRaised + msg.value > fundraisingGoal) {
            effectiveContribution = fundraisingGoal - totalRaised;
            payable(msg.sender).transfer(msg.value - effectiveContribution);
        }

        if (contributions[msg.sender].amount == 0) {
            contributors.push(Contributor(msg.sender, tierDivisor));
            contributions[msg.sender] = ContributionAmount(0, contributors.length - 1);
        } else {
            if (contributors[contributions[msg.sender].index].tierDivisor != tierDivisor) {
                revert("You already contributed in another tier");
            }
        }

        contributions[msg.sender].amount += effectiveContribution;
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

    function claim() external {
        require(fundraisingFinalized, "fundraising not finalized");
        ContributionAmount memory c = contributions[msg.sender];
        if (c.amount == 0) {
            revert("You did not contribute");
        }
        if (claimed[msg.sender]) {
            revert("Already claimed");
        }
        uint256 contribution = contributions[msg.sender].amount;
        uint256 tokensToMint =
            (contribution * supplyToFundraisers) / totalAdjustedContributions / contributors[c.index].tierDivisor;
        DaosWorldClaim(daosWorldClaim).sendDaoToken(msg.sender, tokensToMint);
        claimed[msg.sender] = true;
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
        bytes32 salt,
        uint256 snipeAmount,
        uint256 ethLpAmount,
        uint256 _supplyToLp
    ) external onlyOwner {
        require(goalReached, "Fundraising goal not reached");
        require(!fundraisingFinalized, "DAO tokens already minted");

        supplyToLp = _supplyToLp;
        supplyToFundraisers = MAX_SUPPLY - supplyToLp;

        DaosWorldV1Token token = new DaosWorldV1Token{salt: salt}(name, symbol);
        daoToken = address(token);
        require(address(token) < WETH, "Invalid salt");

        for (uint256 i = 0; i < contributors.length; i++) {
            address contributor = contributors[i].addr;
            uint256 contribution = contributions[contributor].amount;
            totalAdjustedContributions += contribution / contributors[i].tierDivisor;
        }

        daosWorldClaim = address(new DaosWorldClaim(address(this), daoToken));
        token.mint(daosWorldClaim, supplyToFundraisers);
        fundraisingFinalized = true;

        // setup the uniswap v3 pool
        uint160 sqrtPriceX96 = initialTick.getSqrtRatioAtTick();
        address pool = UNISWAP_V3_FACTORY.createPool(address(token), WETH, UNI_V3_FEE);
        IUniswapV3Factory(pool).initialize(sqrtPriceX96);

        int24 minTick = -887200;
        int24 maxTick = 887200;
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams(
            address(token),
            WETH,
            UNI_V3_FEE,
            minTick,
            maxTick,
            supplyToLp,
            ethLpAmount,
            0,
            0,
            address(this),
            block.timestamp
        );

        // mint 100M more tokens for LP
        token.mint(address(this), supplyToLp);
        // transfer ownership to 0 address so no more tokens can be minted
        token.renounceOwnership();

        token.approve(address(POSITION_MANAGER), supplyToLp);
        (uint256 tokenId,,,) = POSITION_MANAGER.mint{value: ethLpAmount}(params);
        POSITION_MANAGER.refundETH();

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
        require(contributions[msg.sender].amount > 0, "No contributions to refund");

        uint256 contributedAmount = contributions[msg.sender].amount;
        contributions[msg.sender].amount = 0;

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

    function setTier(uint256 newTierDivisor) external {
        require(msg.sender == owner() || msg.sender == protocolAdmin, "Must be owner or protocolAdmin");
        require(newTierDivisor > 0, "Tier divisor must be > 0");
        require(!fundraisingFinalized, "Fundraising already finalized");

        tierDivisor = newTierDivisor;
        emit TierSet(newTierDivisor);
    }

    function setMinContributionAmount(uint256 _minContributionAmount) external {
        require(msg.sender == owner() || msg.sender == protocolAdmin, "Must be owner or protocolAdmin");
        minContributionAmount = _minContributionAmount;
    }

    function setGoalReached() external {
        require(msg.sender == owner() || msg.sender == protocolAdmin, "Must be owner or protocolAdmin");
        goalReached = true;
    }
}
