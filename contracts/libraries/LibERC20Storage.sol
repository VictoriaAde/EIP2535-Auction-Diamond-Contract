// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

struct LibERC20Storage {
    string _name;
    string _symbol;
    uint8 _decimal;
    uint256 _totalSupply;
    mapping(address => uint256) _balances;
    mapping(address => mapping(address => uint256)) _allowances;
    address _owner;
}
