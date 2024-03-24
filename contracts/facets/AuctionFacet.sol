// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibAppStorage} from "../libraries/LibAppStorage.sol";
import {IERC721} from "../interfaces/IERC721.sol";
import {IIERC165} from "../interfaces/IERC165.sol";
import {IERC1155} from "../interfaces/IERC1155.sol";

contract AuctionFacet {
    LibAppStorage.Layout internal l;

    /**
     * @notice Creates a new auction.
     * @dev Depending on the type of NFT, verifies ownership before creating the auction.
     * @param _duration Duration of the auction.
     * @param _startingBid Starting bid for the auction.
     * @param _nftId ID of the NFT.
     * @param _nftAddress Address of the NFT contract.
     */
    function createAuction(
        uint256 _duration,
        uint256 _startingBid,
        uint256 _nftId,
        address _nftAddress
    ) public {
        require(_nftAddress != address(0), "No zero address call");

        // Check if the NFT contract supports ERC721 interface
        if (
            IIERC165(_nftAddress).supportsInterface(type(IERC721).interfaceId)
        ) {
            require(
                IERC721(_nftAddress).ownerOf(_nftId) == msg.sender,
                "AuctionFacet: Not owner of NFT"
            );
        }
        // Check if the NFT contract supports ERC1155 interface
        else if (
            IIERC165(_nftAddress).supportsInterface(type(IERC1155).interfaceId)
        ) {
            require(
                IERC1155(_nftAddress).balanceOf(msg.sender, _nftId) > 0,
                "AuctionFacet: Not owner of NFT"
            );
        } else {
            revert("AuctionFacet: Invalid NFT contract");
        }

        // Increment auction count and initialize auction details
        uint256 auctionId = l.auctionCount + 1;
        LibAppStorage.AuctionDetails storage a = l.Auctions[auctionId];
        a.duration = _duration;
        a.startingBid = _startingBid;
        a.nftId = _nftId;
        a.nftAddress = _nftAddress;

        l.auctionCount = l.auctionCount + 1;
    }

    /**
     * @notice Places a bid on an auction.
     * @param _amount Amount of bid.
     * @param _auctionId ID of the auction.
     */
    function placeBid(uint256 _amount, uint256 _auctionId) public {
        LibAppStorage.AuctionDetails storage a = l.Auctions[_auctionId];
        // Ensure the sender is not already the highest bidder
        require(
            a.highestBidder != msg.sender,
            "AuctionFacet: Already highest bidder"
        );
        // Ensure bid amount is not less than the starting bid
        require(
            a.startingBid <= _amount,
            "AuctionFacet: Bid amount is less than starting bid"
        );
        // Ensure the auction has not ended
        require(
            a.duration > block.timestamp,
            "AuctionFacet: Auction has ended"
        );

        // Check sender's balance
        uint balance = l.balances[msg.sender];
        require(balance >= _amount, "AuctionFacet: Not enough balance to bid");

        // Transfer bid amount to the contract
        if (a.currentBid == 0) {
            LibAppStorage._transferFrom(msg.sender, address(this), _amount);
            a.highestBidder = msg.sender;
            a.currentBid = _amount;
        } else {
            // Calculate minimum bid increment
            uint check = ((a.currentBid * 20) / 100) + a.currentBid;
            if (_amount < check) {
                revert("Unprofitable Bid");
            }
            // Transfer bid amount to the contract
            LibAppStorage._transferFrom(msg.sender, address(this), _amount);
            // Pay the previous bidder
            _payPreviousBidder(_auctionId, _amount, a.currentBid);

            // Update auction details
            a.previousBidder = a.highestBidder;
            a.highestBidder = msg.sender;
            a.currentBid = _amount;

            // Handle transaction costs
            _handleTransactionCosts(_auctionId, _amount);
            // Pay the last interactor
            payLastInteractor(_auctionId, a.highestBidder);
        }
    }

    /**
     * @notice Claims the reward for the highest bidder of an auction.
     * @param _auctionId ID of the auction.
     */
    function claimReward(uint256 _auctionId) public {
        LibAppStorage.AuctionDetails storage a = l.Auctions[_auctionId];
        // Ensure sender is the highest bidder
        require(
            a.highestBidder == msg.sender,
            "AuctionFacet: Only highest bidder can claim reward"
        );
        // Ensure auction duration has ended
        require(
            a.duration <= block.timestamp,
            "AuctionFacet: Auction duration has not ended"
        );

        // Check if the NFT is ERC1155 or ERC721
        if (
            IIERC165(a.nftAddress).supportsInterface(type(IERC1155).interfaceId)
        ) {
            // Transfer ERC1155 token to the winner
            IERC1155(a.nftAddress).safeTransferFrom(
                address(this),
                msg.sender,
                a.nftId,
                1,
                ""
            );
        } else if (
            IIERC165(a.nftAddress).supportsInterface(type(IERC721).interfaceId)
        ) {
            // Transfer ERC721 token to the winner
            IERC721(a.nftAddress).safeTransferFrom(
                address(this),
                msg.sender,
                a.nftId
            );
        } else {
            revert("AuctionFacet: Invalid NFT type");
        }

        // Reset auction details
        a.highestBidder = address(0);
        a.currentBid = 0;
        a.previousBidder = address(0);
        a.duration = 0;
        a.startingBid = 0;
        a.nftId = 0;
        a.nftAddress = address(0);
    }

    /**
     * @notice Pays the previous bidder when a new bid is placed.
     * @param _auctionId ID of the auction.
     * @param _amount Amount of the new bid.
     * @param _previousBid Amount of the previous bid.
     */
    function _payPreviousBidder(
        uint256 _auctionId,
        uint256 _amount,
        uint256 _previousBid
    ) private {
        LibAppStorage.AuctionDetails storage a = l.Auctions[_auctionId];
        // Ensure there is a previous bidder
        require(
            a.previousBidder != address(0),
            "AuctionFacet: No previous bidder"
        );

        // Calculate payment amount to the previous bidder
        uint256 paymentAmount = ((_amount * LibAppStorage.PreviousBidder) /
            100) + _previousBid;
        // Transfer funds to the previous bidder
        LibAppStorage._transferFrom(
            address(this),
            a.previousBidder,
            paymentAmount
        );
    }

    /**
     * @notice Handles transaction costs including burn, DAO fees, and team fees.
     * @param _auctionId ID of the auction.
     * @param _amount Amount of the bid.
     */
    function _handleTransactionCosts(
        uint256 _auctionId,
        uint256 _amount
    ) private {
        LibAppStorage.AuctionDetails storage a = l.Auctions[_auctionId];
        // Handle burning of tokens
        uint256 burnAmount = (_amount * LibAppStorage.Burnable) / 100;
        LibAppStorage._burn(a.previousBidder, burnAmount);

        // Transfer DAO fees
        uint256 daoAmount = (_amount * LibAppStorage.DAO) / 100;
        LibAppStorage._transferFrom(
            address(this),
            LibAppStorage.DAOAddress,
            daoAmount
        );

        // Transfer team fees
        uint256 teamAmount = (_amount * LibAppStorage.TeamWallet) / 100;
        LibAppStorage._transferFrom(
            address(this),
            LibAppStorage.TeamWalletAddress,
            teamAmount
        );
    }

    /**
     * @notice Pays the last interactor with a percentage of the current bid amount.
     * @param _auctionId ID of the auction.
     * @param _lastInteractor Address of the last interactor.
     */
    function payLastInteractor(
        uint256 _auctionId,
        address _lastInteractor
    ) private {
        LibAppStorage.AuctionDetails storage a = l.Auctions[_auctionId];
        // Ensure there is a last interactor
        require(
            _lastInteractor != address(0),
            "AuctionFacet: No last interactor"
        );

        // Calculate payment amount for the last interactor
        uint256 paymentAmount = (a.currentBid * 1) / 100;
        // Transfer funds to the last interactor
        LibAppStorage._transferFrom(
            address(this),
            _lastInteractor,
            paymentAmount
        );
    }
}

// // A diamond that acts as an auction house, auction are zero-loss meaning all participants gain something once they are outbid

// // sample

// // if an NFT is auction and a bidder A bids 50 AUC erc tokens, the tokens are trnasferred to the diamond, if he is outbid, his tokens are transferred back with an incentive calculated below

// // 10% of highestBid==totalFee

// // 2% of totalFee is burned
// // 2% of totalFee is sent to a random DAO address(just random)
// // 3% goes back to the outbid bidder
// // 2% goes to the team wallet(just random)
// // 1% is sent to the last address to interact with AUCToken(write calls like transfer,transferFrom,approve,mint etc)

// // the diamond should also be the AUC erc20 tokn contract e.g AUCFacet

// // note:

// // - make use of libraries
// // - your diamond should support both erc721 and erc1155 and both as a collection
// // - make use of libraries 2
// // -tests...of course

// // bid should have timeline.

// // When they bid
