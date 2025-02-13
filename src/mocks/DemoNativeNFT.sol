//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/// @title DemoNativeNFT
/// @notice
/// @dev
contract DemoNativeNFT is Ownable, AccessControl, ERC721URIStorage {
    using Strings for uint256;

    uint256 public tokenIdCounter;
    string public baseTokenURI;
    uint256 public mintPrice;

    event PaymentTokenSet(address indexed paymentToken);
    event MintPriceSet(uint256 indexed mintPrice);
    event BaseURISet(string indexed baseURI);

    constructor(address _owner, string memory _baseTokenURI, uint256 _mintPrice)
        Ownable(_owner)
        ERC721("DemoNFT", "DMON")
    {
        tokenIdCounter = 0;
        baseTokenURI = _baseTokenURI;
        mintPrice = _mintPrice;
    }

    ////////////////////////////////////////////////////////////////////////
    /// Internal functions
    ////////////////////////////////////////////////////////////////////////

    function _baseURI() internal view override returns (string memory) {
        return baseTokenURI;
    }

    ////////////////////////////////////////////////////////////////////////
    /// Owner actions
    ////////////////////////////////////////////////////////////////////////

    function _transferOwnership(address newOwner) internal virtual override {
        super._transferOwnership(newOwner);
        _grantRole(DEFAULT_ADMIN_ROLE, newOwner);
    }

    /// @notice set a new baseTokenURI
    /// @param _baseTokenURI the new base token URI
    function setBaseURI(string memory _baseTokenURI) public onlyOwner {
        baseTokenURI = _baseTokenURI;
        emit BaseURISet(_baseTokenURI);
    }

    function setMintPrice(uint256 _mintPrice) public onlyOwner {
        mintPrice = _mintPrice;
        emit MintPriceSet(_mintPrice);
    }

    ////////////////////////////////////////////////////////////////////////
    /// Minter action
    ////////////////////////////////////////////////////////////////////////

    /// @notice mint a NFT

    function mint(string memory _tokenURI) public payable returns (uint256) {
        require(msg.value == mintPrice, "Insufficient ETH sent");

        unchecked {
            ++tokenIdCounter;
        }
        uint256 newItemId = tokenIdCounter;
        _safeMint(msg.sender, newItemId);
        _setTokenURI(newItemId, _tokenURI);
        return newItemId;
    }

    ////////////////////////////////////////////////////////////////////////
    /// Interface functions
    ////////////////////////////////////////////////////////////////////////

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721URIStorage, AccessControl)
        returns (bool)
    {
        return ERC721URIStorage.supportsInterface(interfaceId) || AccessControl.supportsInterface(interfaceId);
    }
}
