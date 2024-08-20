// MockERC20.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin-Defaultpool/contracts/token/ERC20/IERC20.sol";

contract MockERC20 is IERC20 {
    mapping(address => uint256) private _balances;

    function totalSupply() external pure override returns (uint256) {
        return 10**24;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        _balances[msg.sender] -= amount;
        _balances[recipient] += amount;
        return true;
    }

    function allowance(address owner, address spender) external pure override returns (uint256) {
        return 0;
    }

    function approve(address spender, uint256 amount) external pure override returns (bool) {
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        _balances[sender] -= amount;
        _balances[recipient] += amount;
        return true;
    }

    function mint(address account, uint256 amount) external {
        _balances[account] += amount;
    }
}
