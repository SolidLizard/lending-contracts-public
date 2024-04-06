// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "./Fund.sol";

contract ScalesTreasuryFund is Fund {
    uint256 public constant ALLOCATION = 1_999_000 ether; // 20%ish
    uint256 public constant VESTING_DURATION = 4 * 365 * 24 * 3600; // 4 years
    uint256 public constant VESTING_START = 1712131200; // April 3rd 2024

    /*===================== VIEWS =====================*/

    function allocation() public pure override returns (uint256) {
        return ALLOCATION;
    }

    function vestingStart() public pure override returns (uint256) {
        return VESTING_START;
    }

    function vestingDuration() public pure override returns (uint256) {
        return VESTING_DURATION;
    }
}
