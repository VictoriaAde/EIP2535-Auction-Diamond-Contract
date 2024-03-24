// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library LibAppStorage {
    event Transfer(address indexed _from, address indexed _to, uint256 _value);

    struct UserBid {
        uint256 amount;
    }

    bytes4 constant erc721Interface = 0x73ad2146;
    bytes4 constant erc1155Interface = 0x973bb640;

    struct Auction {
        address owner;
        uint256 nftId;
        uint256 highestBid;
        bool settled;
        address randomDAOAddress;
        address lastInteractionAddress;
    }

    struct Bid {
        address bidder;
        uint amount;
        uint auctionId;
    }

    struct Layout {
        //ERC20
        string name;
        string symbol;
        uint256 totalSupply;
        uint8 decimals;
        mapping(address => uint256) balances;
        mapping(address => mapping(address => uint256)) allowances;
        //BIDDING
        address rewardNFT;
        uint256 rewardRate;
        mapping(address => UserBid) userDetails;
        address[] bidders;
        uint256 lastBidTime;
        mapping(uint256 => Auction) auctions;
        mapping(uint256 => Bid) bids;
        uint256 nextAuctionId;
        uint256 randNonce;
        address teamWallet;
    }

    function layoutStorage() internal pure returns (Layout storage l) {
        assembly {
            l.slot := 0
        }
    }

    function _transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) internal {
        Layout storage l = layoutStorage();
        uint256 frombalances = l.balances[msg.sender];
        require(
            frombalances >= _amount,
            "ERC20: Not enough tokens to transfer"
        );
        l.balances[_from] = frombalances - _amount;
        l.balances[_to] += _amount;
        emit Transfer(_from, _to, _amount);
    }

    function _burn(address account, uint256 amount) internal {
        Layout storage l = layoutStorage();

        require(account != address(0), "ERC20: burn from the zero address");
        uint256 accountBalance = l.balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");

        unchecked {
            l.balances[account] = accountBalance - amount;
            l.totalSupply -= amount;
        }
        emit Transfer(account, address(0), amount);
    }
}
