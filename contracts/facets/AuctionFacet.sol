// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibAppStorage} from "../libraries/LibAppStorage.sol";

contract AuctionFacet {
    LibAppStorage.Layout internal l;

    event AuctionStarted(uint256 auctionId, bytes32 nftId, uint256 startingBid);
    event BidPlaced(uint256 auctionId, address bidder, uint256 amount);
    event AuctionSettled(uint256 auctionId, address winner, uint256 finalPrice);

    function startAuction(bytes32 _nftId, uint256 _startingBid) public {
        uint256 auctionId = l.nextAuctionId + 1;

        l.auctions[auctionId] = LibAppStorage.Auction(
            msg.sender,
            _nftId,
            _startingBid,
            false,
            address(0)
        );

        l.nextAuctionId++;

        emit AuctionStarted(auctionId, _nftId, _startingBid);
    }

    function placeBid(uint256 auctionId, uint256 amount) public {
        require(
            !l.auctions[auctionId].settled,
            "Auction has already been settled"
        );
        require(
            amount > l.auctions[auctionId].highestBid,
            "Bid must be higher than the current highest bid"
        );

        // Transfer AUC tokens from the bidder to the contract
        // This requires an approval and transferFrom call from the ERC20Facet
        IERC20 aucToken = IERC20(l.aucToken);
        require(
            aucToken.allowance(msg.sender, address(this)) >= amount,
            "Not enough allowance to transfer"
        );
        aucToken.transferFrom(msg.sender, address(this), amount);

        // Update the highest bid and bidder
        l.auctions[auctionId].highestBid = amount;
        l.auctions[auctionId].owner = msg.sender;
        l.auctions[auctionsId].lastInteractionAddress = msg.sender

        emit BidPlaced(auctionId, msg.sender, amount);
    }

    function settleAuction(uint256 auctionId) public {
        require(
            !l.auctions[auctionId].settled,
            "Auction has already been settled"
        );

        l.auctions[auctionId].settled = true;
        uint256 totalFee = calculateFee(auctionId);
        uint256 burnAmount = (totalFee * 2) / 100; // 2% of totalFee
        uint256 daoAmount = (totalFee * 2) / 100; // 2% of totalFee
        uint256 outbidAmount = (totalFee * 3) / 100; // 3% of totalFee
        uint256 teamAmount = (totalFee * 2) / 100; // 2% of totalFee
        uint256 lastInteractionAmount = (totalFee * 1) / 100; // 1% of totalFee

        // Burn tokens
        IERC20 aucToken = IERC20(l.aucToken);
        aucToken.burn(burnAmount);

        // Send to random DAO address
        address randomDAOAddress = generateRandomAddress();
        aucToken.transfer(randomDAOAddress, daoAmount);

        // Refund outbid bidder
        aucToken.transfer(l.auctions[auctionId].owner, outbidAmount);

        // Send to team wallet
        aucToken.transfer(l.teamWallet, teamAmount);

        // Send to last interaction address
        // This requires finding the last interaction address and transferring the last interaction amount

        aucToken.transfer(lastInteractionAddress, lastInteractionAmount);

        IERC20._burn(msg.sender, amount);

        emit AuctionSettled(
            auctionId,
            l.auctions[auctionId].owner,
            l.auctions[auctionId].highestBid
        );
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

    function calculateFee(uint256 auctionId) private view returns (uint256) {
        return (l.auctions[auctionId].highestBid * 10) / 100; // 10% of the highest bid
    }

    // Additional functions for generating random addresses, finding the last interaction address, etc.
}