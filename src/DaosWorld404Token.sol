//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {DN404} from "dn404/src/DN404.sol";

/// @dev This is the ERC20 contract for the token.
contract DaosWorld404Token is Ownable, DN404 {
    address public tokenBaseURISetter;
    string public tokenBaseURI;
    string internal _name;
    string internal _symbol;

    /// @dev We try to keep the constructor argless to simplify verification
    /// computation of the salt. Since we have a factory, we can use `initialize`.
    constructor() Ownable(msg.sender) {}

    /// @dev Initializes the contract.
    function initialize(
        string memory name_,
        string memory symbol_,
        string memory tokenBaseURI_,
        address mirror,
        uint256 maxTotalSupplyERC721_,
        address initialOwner,
        address initialSupplyOwner,
        address initialTokenBaseURISetter
    ) public onlyOwner {
        _transferOwnership(initialOwner);
        _name = name_;
        _symbol = symbol_;
        tokenBaseURI = tokenBaseURI_;
        tokenBaseURISetter = initialTokenBaseURISetter;
        // `_initializeDN404` cannot be called twice,
        // so we are protected against reinitialization.
        _initializeDN404(maxTotalSupplyERC721_ * _unit(), initialSupplyOwner, mirror);
    }

    /// @dev Returns the name. The NFT contract will use this as well.
    function name() public view override returns (string memory) {
        return _name;
    }

    /// @dev Returns the symbol. The NFT contract will use this as well.
    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    /// @dev Override for the token URI.
    /// This internal function will be queried by the NFT contract via the `fallback()`.
    function _tokenURI(uint256 id) internal view override returns (string memory) {
        if (!_exists(id)) revert TokenDoesNotExist();
        return bytes(tokenBaseURI).length != 0 ? string.concat(tokenBaseURI, Strings.toString(id)) : "";
    }

    /// @dev Allows the owner or a base URI setter to set the base token URI.
    function setTokenBaseURI(string memory tokenBaseURI_) public {
        require(msg.sender == owner() || msg.sender == tokenBaseURISetter);
        tokenBaseURI = tokenBaseURI_;
    }

    /// @dev Allows the owner or a base URI setter to update the authorized
    /// base URI setter. The authorized base URI setter will also be reflected
    function setTokenBaseURISetter(address newSetter) public {
        require(msg.sender == owner() || msg.sender == tokenBaseURISetter);
        tokenBaseURISetter = newSetter;
        (bool success,) = mirrorERC721().call(abi.encodeWithSignature("tokenBaseURISetter()"));
        require(success);
    }

    /// @dev Returns all the token IDs owned by the user.
    function owned(address user) public view returns (uint256[] memory) {
        return _ownedIds(user, 0, type(uint256).max);
    }

    /// @dev Allows an address to set whether they want to skip automatic minting
    /// of NFTs corresponding to ERC20 token transfers.
    function setSkipNFT(bool value) public override returns (bool) {
        bool original = getSkipNFT(msg.sender);
        super.setSkipNFT(value);
        // If the state transitions from `true` to `false`, auto-mint all possible NFTs.
        if (original && !getSkipNFT(msg.sender)) {
            transfer(msg.sender, balanceOf(msg.sender));
        }
        return true;
    }

    /// @dev This override makes the default `true`. We don't want finalize to waste gas.
    /// Additionally, since all accounts are exempt from auto-minting NFTs by default,
    /// we don't need an admin-only function to manually make LPs exempt.
    function _skipNFTDefault() internal view virtual override returns (SkipNFTDefault) {
        return SkipNFTDefault.On;
    }
}
