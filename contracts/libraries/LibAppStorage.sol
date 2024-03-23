// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library LibAppStorage {
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    struct UserBid {
        uint256 amount;
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
    }
}
