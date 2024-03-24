// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract RokiMarsNFT is ERC721, ERC721URIStorage {
    uint256 private nextTokenId;

    constructor() ERC721("RokiMarsNFT", "RKT") {}

    function safeMint(address to, string memory uri) public returns (uint256) {
        uint256 _tokenId = nextTokenId++;
        _safeMint(to, _tokenId);
        _setTokenURI(_tokenId, uri);
        return _tokenId;
    }

    // The following functions are overrides required by Solidity.
    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
