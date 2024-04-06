// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IToken} from "./interfaces/IToken.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract SCALES is IToken, ERC20Permit {
    address public minter;
    address private owner;

    error OnlyOwner(address owner);

    constructor() ERC20("SCALES", "SCALES") ERC20Permit("SCALES") {
        minter = msg.sender;
        owner = msg.sender;
        _mint(msg.sender, 3900000000000000000000000); // 3.9M (dev(vested) + treasury(vested) + liq)
    }
   
    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner(owner);
        _;
    }

    function setMinter(address _minter) external {
        if (msg.sender != minter) revert NotMinter();
        minter = _minter;
    }


    function mint(address account, uint256 amount) external returns (bool) {
        if (msg.sender != minter ) revert NotMinter();
        require(totalSupply() + amount <= 10_000_000 ether, "more than xScales max totalSupply");
        _mint(account, amount);
        return true;
    }

}
