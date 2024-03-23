// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library LibAppStorage {
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    struct UserBid {
        uint256 amount;
    }

    bytes4 constant ERC721 = 0x73ad2146;
    bytes4 constant ERC1155 = 0x973bb640;

    struct Auction {
        address owner;
        bytes32 nftId;
        uint256 highestBid;
        bool settled;
        address randomDAOAddress;
        address lastInteractionAddress;
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
        uint256 nextAuctionId;
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
}
