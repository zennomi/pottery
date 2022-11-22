// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/ISBT721.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableMapUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

// Soul Bound Token Contract (SBT)
contract SBT is ISBT721, AccessControlUpgradeable, OwnableUpgradeable {
    using StringsUpgradeable for uint256;
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using EnumerableMapUpgradeable for EnumerableMapUpgradeable.AddressToUintMap;
    using EnumerableMapUpgradeable for EnumerableMapUpgradeable.UintToAddressMap;

    // tokenId => owner
    EnumerableMapUpgradeable.UintToAddressMap private ownerMap;

    // owner => tokenId
    EnumerableMapUpgradeable.AddressToUintMap private tokenMap;

    // Token Id
    CountersUpgradeable.Counter private _tokenId;

    // Token name
    string public name;

    // Token symbol
    string public symbol;

    // Token URI
    string private _baseTokenURI;

    // Operator role fot attesting and revoking
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /**
     * name_ is name of account bound token contract
     * symbol_ is symbol of account bound token contract
     * admin_ is admin of account bound token contract (operator)
     */
    function initialize(
        string memory name_,
        string memory symbol_,
        address admin_
    ) external initializer {
        __AccessControl_init();
        __Ownable_init();

        name= name_;
        symbol = symbol_;

        // grant DEFAULT_ADMIN_ROLE to contract creator
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(OPERATOR_ROLE, admin_);
    }
    
    /*
     * attest soulbound token to user  
     * @to is the address of the owner to attest account bound token
     */
    function attest(address to) external override returns (uint256) {
        require(
            hasRole(OPERATOR_ROLE, _msgSender()),
            "Only the account with OPERATOR_ROLE can attest the SBT!"
        );
        require(to != address(0), "Address is empty!");
        require(!tokenMap.contains(to), "SBT already exists!");

        _tokenId.increment();
        uint256 tokenId = _tokenId.current();

        tokenMap.set(to, tokenId);
        ownerMap.set(tokenId, to);

        emit Attest(to, tokenId);
        emit Transfer(address(0), to, tokenId);

        return tokenId;
    }

    /*
     * attest batch of soulbound token to users
     * addrs are list of users address
     */
    function batchAttest(address[] calldata addrs) external {
        uint256 addrLength = addrs.length;

        require(
            hasRole(OPERATOR_ROLE, _msgSender()),
            "Only the account with OPERATOR_ROLE can attest the SBT!"
        );
        require(addrLength <= 100, "The max length of addresses is 100!");

        for (uint8 i = 0; i < addrLength; i++) {
            address to = addrs[i];

            if (to == address(0) || tokenMap.contains(to)) {
                continue;
            }

            _tokenId.increment();
            uint256 tokenId = _tokenId.current();

            tokenMap.set(to, tokenId);
            ownerMap.set(tokenId, to);

            emit Attest(to, tokenId);
            emit Transfer(address(0), to, tokenId);
        }
    }

    /*
     * revoke soulbound token from user
     * @from is the address of the owner to revoke soulbound token
     */
    function revoke(address from) external override {
        require(
            hasRole(OPERATOR_ROLE, _msgSender()),
            "Only the account with OPERATOR_ROLE can revoke the SBT!"
        );
        require(from != address(0), "Address is empty!");
        require(tokenMap.contains(from), "The account does not have any SBT!");

        uint256 tokenId = tokenMap.get(from);

        tokenMap.remove(from);
        ownerMap.remove(tokenId);

        emit Revoke(from, tokenId);
        emit Transfer(from, address(0), tokenId);
    }

    /*
     * revoke batch of soulbound token from users
     * addrs are list of users address
     */
    function batchRevoke(address[] calldata addrs) external {
        uint256 addrLength = addrs.length;

        require(
            hasRole(OPERATOR_ROLE, _msgSender()),
            "Only the account with OPERATOR_ROLE can revoke the SBT!"
        );
        require(addrLength <= 100, "The max length of addresses is 100!");

        for (uint8 i = 0; i < addrLength; i++) {
            address from = addrs[i];

            if (from == address(0) || !tokenMap.contains(from)) {
                continue;
            }

            uint256 tokenId = tokenMap.get(from);

            tokenMap.remove(from);
            ownerMap.remove(tokenId);

            emit Revoke(from, tokenId);
            emit Transfer(from, address(0), tokenId);
        }
    }

    /*
     * user can burn their soulbound token
     */
    function burn() external override {
        address sender = _msgSender();

        require(
            tokenMap.contains(sender),
            "The account does not have any SBT!"
        );

        uint256 tokenId = tokenMap.get(sender);

        tokenMap.remove(sender);
        ownerMap.remove(tokenId);

        emit Burn(sender, tokenId);
        emit Transfer(sender, address(0), tokenId);
    }

    /**
     * @dev Update _baseTokenURI
     */
    function setBaseTokenURI(string calldata uri) public {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "Only the account with DEFAULT_ADMIN_ROLE can set the base token URI!"
        );

        _baseTokenURI = uri;
    }

    /*
     * balanceOf returns the number of soulbound token owned by the user
     */
    function balanceOf(address owner) external view override returns (uint256) {
        (bool success, ) = tokenMap.tryGet(owner);
        return success ? 1 : 0;
    }

    /*
     * get account soulbound token id of the user
     */
    function tokenIdOf(address from) external view override returns (uint256) {
        return tokenMap.get(from, "The wallet has not attested any SBT!");
    }

    /*
     * ownerOf returns the owner of the soulbound token
     */
    function ownerOf(uint256 tokenId) external view override returns (address) {
        return ownerMap.get(tokenId, "Invalid tokenId!");
    }

    /*
     * get total supply of soulbound token
     */
    function totalSupply() external view override returns (uint256) {
        return tokenMap.length();
    }

    /*
     * check address is operator or not
     */
    function isOperator(address account) external view returns (bool) {
        return hasRole(OPERATOR_ROLE, account);
    }

    /*
     * check address is admin or not
     */
    function isAdmin(address account) external view returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, account);
    }

    /**
     * get token URI
     */
    function tokenURI(uint256 tokenId) external view returns (string memory) {
        return
            bytes(_baseTokenURI).length > 0
                ? string(abi.encodePacked(_baseTokenURI, tokenId.toString()))
                : "";
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return
            interfaceId == type(IERC721Upgradeable).interfaceId ||
            interfaceId == type(IERC721MetadataUpgradeable).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}