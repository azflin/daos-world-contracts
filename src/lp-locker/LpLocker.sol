// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {INonfungiblePositionManager} from "../interfaces/IUniswap.sol";

contract LpLocker is Ownable, IERC721Receiver {
    event ERC721Released(address indexed token, uint256 amount);

    event LockId(uint256 _id);

    event LockDuration(uint256 _time);
    event Received(address indexed from, uint256 tokenId);

    event ClaimedFees(
        address indexed claimer,
        address indexed token0,
        address indexed token1,
        uint256 amount0,
        uint256 amount1,
        uint256 totalAmount1,
        uint256 totalAmount0
    );

    mapping(address => uint256) public _erc721Released;
    IERC721 private SafeERC721;
    uint256 public fundExpiry;
    address private immutable e721Token;
    bool private flag;
    // Whether the V3 LP NFT has been unlocked and sent back to the DAO
    bool public unlocked;
    INonfungiblePositionManager private positionManager;
    string public constant version = "0.0.1";
    uint256 public _protocolFee;
    address public _protocolAdmin;
    address public _daoTreasury;

    /**
     * @dev Sets the sender as the initial owner, the beneficiary as the pending owner, and the duration for the lock
     * vesting duration of the vesting wallet.
     */
    // 0x7449192807269103160ac4857a3d5bb66539d493
    constructor(
        address v3PositionManager,
        address daoManager, // this is the token deployer
        uint256 _fundExpiry,
        uint256 protocolFee, //60
        address protocolAdmin, // 0x04F6ef12a8B6c2346C8505eE4Cff71C43D2dd825
        address daoTreasury // LP token gets sent here after release
    ) payable Ownable(daoManager) {
        fundExpiry = _fundExpiry;
        SafeERC721 = IERC721(v3PositionManager);
        //already false but lets be safe
        flag = false;
        e721Token = v3PositionManager;
        _protocolFee = protocolFee;
        _protocolAdmin = protocolAdmin;
        _daoTreasury = daoTreasury;
        emit LockDuration(_fundExpiry);
    }

    function initializer(uint256 token_id) public {
        require(flag == false, "contract already initialized");
        _erc721Released[e721Token] = token_id;
        flag = true;
        positionManager = INonfungiblePositionManager(e721Token);
        emit LockId(token_id);
    }

    /**
     * @dev The contract should be able to receive Eth.
     */
    receive() external payable virtual {}

    /**
     * @dev returns the tokenId of the locked LP
     */
    function released(address token) public view virtual returns (uint256) {
        return _erc721Released[token];
    }

    /**
     * @dev Release the token that have already vested.
     *
     * Emits a {ERC721Released} event.
     */
    function release() public virtual {
        if (timeUntilFundExpiry() != 0 || unlocked) {
            revert();
        }
        uint256 id = _erc721Released[e721Token];
        emit ERC721Released(e721Token, id);
        SafeERC721.transferFrom(address(this), _daoTreasury, id);
        unlocked = true;
    }

    /**
     * @dev sourced from: https://docs.uniswap.org/contracts/v3/reference/deployments
     */
    function _getAddresses()
        internal
        view
        returns (address weth, INonfungiblePositionManager nonFungiblePositionManager)
    {
        uint256 chainId = block.chainid;
        // base
        if (chainId == 8453) {
            weth = 0x4200000000000000000000000000000000000006;
            nonFungiblePositionManager = INonfungiblePositionManager(0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1);
        }
        // degen chain
        if (chainId == 666666666) {
            // wrapped degen
            weth = 0xEb54dACB4C2ccb64F8074eceEa33b5eBb38E5387;
            nonFungiblePositionManager = INonfungiblePositionManager( // proxy swap
            0x56c65e35f2Dd06f659BCFe327C4D7F21c9b69C2f);
        }

        if (chainId == 5112) {
            // wrapped ETH
            weth = 0x4200000000000000000000000000000000000006;
            nonFungiblePositionManager = INonfungiblePositionManager( // proxy swap
            0xD088322Fa988225B3936555894E1D21c1A727859);
        }
    }

    //Use collect fees to collect the fees
    function collectFees(uint256 _tokenId) public {
        require(owner() == msg.sender || _protocolAdmin == msg.sender, "only owner or protocolAdmin can call");
        (, INonfungiblePositionManager nonfungiblePositionManager) = _getAddresses();

        if (_protocolFee == 0) {
            (uint256 amount0, uint256 amount1) = nonfungiblePositionManager.collect(
                INonfungiblePositionManager.CollectParams({
                    recipient: owner(),
                    amount0Max: type(uint128).max,
                    amount1Max: type(uint128).max,
                    tokenId: _tokenId
                })
            );

            emit ClaimedFees(owner(), address(0), address(0), amount0, amount1, amount0, amount1);
        } else {
            (uint256 amount0, uint256 amount1) = nonfungiblePositionManager.collect(
                INonfungiblePositionManager.CollectParams({
                    recipient: address(this),
                    amount0Max: type(uint128).max,
                    amount1Max: type(uint128).max,
                    tokenId: _tokenId
                })
            );

            (,, address token0, address token1,,,,,,,,) = positionManager.positions(_tokenId);

            IERC20 feeToken0 = IERC20(token0);
            IERC20 feeToken1 = IERC20(token1);

            uint256 protocolFee0 = (amount0 * _protocolFee) / 100;
            uint256 protocolFee1 = (amount1 * _protocolFee) / 100;

            uint256 recipientFee0 = amount0 - protocolFee0;
            uint256 recipientFee1 = amount1 - protocolFee1;

            feeToken0.transfer(owner(), recipientFee0);
            feeToken1.transfer(owner(), recipientFee1);

            feeToken0.transfer(_protocolAdmin, protocolFee0);
            feeToken1.transfer(_protocolAdmin, protocolFee1);

            emit ClaimedFees(owner(), token0, token1, recipientFee0, recipientFee1, amount0, amount1);
        }
    }

    // When dao treasury extends fund expiry, the locker must extend fund expiry too
    function extendFundExpiry(uint256 newFundExpiry) public {
        require(msg.sender == _daoTreasury, "Must be called by dao treasury contract");
        require(newFundExpiry > fundExpiry, "Must be later fundexpiry");
        fundExpiry = newFundExpiry;
    }

    function timeUntilFundExpiry() public view returns (uint256) {
        if (block.timestamp > fundExpiry) {
            return 0;
        } else {
            return fundExpiry - block.timestamp;
        }
    }

    function onERC721Received(address, address from, uint256 id, bytes calldata data)
        external
        override
        returns (bytes4)
    {
        emit Received(from, id);

        return IERC721Receiver.onERC721Received.selector;
    }
}
