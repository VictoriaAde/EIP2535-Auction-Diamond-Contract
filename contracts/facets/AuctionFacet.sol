// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibAppStorage} from "../libraries/LibAppStorage.sol";

contract AuctionFacet {
    LibAppStorage.Layout internal l;

    event AuctionStarted(uint256 auctionId, uint256 nftId, uint256 startingBid);
    event BidPlaced(uint256 auctionId, address bidder, uint256 amount);
    event AuctionSettled(uint256 auctionId, address winner, uint256 finalPrice);

    function startAuction(uint256 _nftId, uint256 _startingBid) public {
        require(msg.sender != address(0), "ZERO_ADDRESS");

        uint256 _auctionId = l.nextAuctionId + 1;

        LibAppStorage.Auction storage s = l.auctions[_auctionId];

        s.owner = msg.sender;
        s.nftId = _nftId;
        s.randomDAOAddress = address(0);
        s.settled = false;
        s.highestBid = _startingBid;
        s.lastInteractionAddress = msg.sender;

        l.nextAuctionId++;

        emit AuctionStarted(_auctionId, _nftId, _startingBid);
    }

    function placeBid(uint256 _auctionId, uint256 _amount) public {
        require(
            !l.auctions[_auctionId].settled,
            "Auction has already been settled"
        );
        require(
            _amount > l.auctions[_auctionId].highestBid,
            "Bid must be higher than the current highest bid"
        );

        // Transfer AUC tokens from the bidder to the contract
        // This requires an approval and transferFrom call from the ERC20Facet

        require(_amount > 0, "NotZero");
        require(msg.sender != address(0));
        uint256 balance = l.balances[msg.sender];
        require(balance >= _amount, "NotEnough");
        LibAppStorage._transferFrom(msg.sender, address(this), _amount);

        // Update the highest bid and bidder
        l.auctions[_auctionId].highestBid = _amount;
        l.auctions[_auctionId].owner = msg.sender;
        l.auctions[_auctionId].lastInteractionAddress = msg.sender;

        emit BidPlaced(_auctionId, msg.sender, _amount);
    }

    function settleAuction(uint256 _auctionId) public {
        require(
            !l.auctions[_auctionId].settled,
            "Auction has already been settled"
        );

        l.auctions[_auctionId].settled = true;
        uint256 totalFee = calculateFee(_auctionId);
        uint256 burnAmount = (totalFee * 2) / 100; // 2% of totalFee
        uint256 daoAmount = (totalFee * 2) / 100; // 2% of totalFee
        uint256 outbidAmount = (totalFee * 3) / 100; // 3% of totalFee
        uint256 teamAmount = (totalFee * 2) / 100; // 2% of totalFee
        uint256 lastInteractionAmount = (totalFee * 1) / 100; // 1% of totalFee

        // LibAppStorage.Bid storage s = l.bids[_auctionId];

        // Send to random DAO address
        address randomDAOAddress = generateRandomAddress();
        LibAppStorage._transferFrom(address(this), randomDAOAddress, daoAmount);

        // Refund outbid bidder
        LibAppStorage._transferFrom(
            address(this),
            l.auctions[_auctionId].owner,
            outbidAmount
        );

        // Send to team ,
        LibAppStorage._transferFrom(address(this), l.teamWallet, teamAmount);
        LibAppStorage._burn(msg.sender, burnAmount);

        // Send to last interaction address
        // This requires finding the last interaction address and transferring the last interaction amount
        LibAppStorage._transferFrom(
            address(this),
            l.auctions[_auctionId].lastInteractionAddress = msg.sender,
            lastInteractionAmount
        );

        emit AuctionSettled(
            _auctionId,
            l.auctions[_auctionId].owner,
            l.auctions[_auctionId].highestBid
        );
    }

    function burn(uint256 amount) public {
        LibAppStorage._burn(msg.sender, amount);
    }

    function calculateFee(uint256 auctionId) private view returns (uint256) {
        return (l.auctions[auctionId].highestBid * 10) / 100; // 10% of the highest bid
    }

    function getBid(uint256 _auctionId) public view returns (uint256) {
        return l.auctions[_auctionId].highestBid;
    }

    function getAuction(
        uint256 _auctionId
    ) public view returns (LibAppStorage.Auction memory) {
        return l.auctions[_auctionId];
    }

    // Additional functions for generating random addresses, finding the last interaction address, etc.

    function generateRandomAddress() public returns (address) {
        l.randNonce++;
        bytes32 randomHash = keccak256(
            abi.encodePacked(block.timestamp, msg.sender, l.randNonce)
        );
        return address(uint160(uint256(randomHash)));
    }

    // function isERC721(address nftContract) public view returns (bool) {
    //     // ERC721 interface ID
    //     // LibAppStorage.erc721Interface = 0x80ac58cd;
    //     return
    //         isERC721(nftContract).supportsInterface(
    //             LibAppStorage.erc721Interface
    //         );
    // }

    // function isERC1155(address nftContract) public view returns (bool) {
    //     // ERC1155 interface ID
    //     LibAppStorage.erc1155Interface = 0xd9b67a26;
    //     return
    //         isERC721(nftContract).supportsInterface(
    //             LibAppStorage.erc1155Interface
    //         );
    // }
}
// function settleAuction(uint256 auctionId) public {
//     require(
//         !l.auctions[auctionId].settled,
//         "Auction has already been settled"
//     );

//     l.auctions[auctionId].settled = true;
//     uint256 totalFee = calculateFee(auctionId);
//     uint256 burnAmount = (totalFee * 2) / 100; // 2% of totalFee
//     uint256 daoAmount = (totalFee * 2) / 100; // 2% of totalFee
//     uint256 outbidAmount = (totalFee * 3) / 100; // 3% of totalFee
//     uint256 teamAmount = (totalFee * 2) / 100; // 2% of totalFee
//     uint256 lastInteractionAmount = (totalFee * 1) / 100; // 1% of totalFee

//     // Burn tokens
//     // This requires a burn function in the ERC20Facet
//     // Example: ERC20Facet.burn(burnAmount);

//     // Send to random DAO address
//     // This requires generating a random address and transferring the amount
//     // Example: payable(randomDAOAddress).transfer(daoAmount);

//     // Refund outbid bidder
//     // This requires transferring the outbid amount back to the outbid bidder
//     // Example: payable(auctions[auctionId].owner).transfer(outbidAmount);

//     // Send to team wallet
//     // This requires transferring the team amount to the team wallet
//     // Example: payable(teamWallet).transfer(teamAmount);

//     // Send to last interaction address
//     // This requires finding the last interaction address and transferring the last interaction amount
//     // Example: payable(lastInteractionAddress).transfer(lastInteractionAmount);

//     emit AuctionSettled(
//         auctionId,
//         l.auctions[auctionId].owner,
//         l.auctions[auctionId].highestBid
//     );
// }

//     A diamond that acts as an auction house, auction are zero-loss meaning all participants gain something once they are outbid

// sample

// if an NFT is auction and a bidder A bids 50 AUC erc tokens, the tokens are trnasferred to the diamond, if he is outbid, his tokens are transferred back with an incentive calculated below

// 10% of highestBid==totalFee

// 2% of totalFee is burned
// 2% of totalFee is sent to a random DAO address(just random)
// 3% goes back to the outbid bidder
// 2% goes to the team wallet(just random)
// 1% is sent to the last address to interact with AUCToken(write calls like transfer,transferFrom,approve,mint etc)

// the diamond should also be the AUC erc20 tokn contract e.g AUCFacet

// note:
// - make use of libraries
// - your diamond should support both erc721 and erc1155 and both as a collection
// - make use of libraries 2
// -tests...of course

// Auctioneers come to your site, display NFTs, Be able to get ID of anyNFT id, so you can display them for sell
