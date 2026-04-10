// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./CornDEX.sol";

interface ILendingRiskUpdater {
    function updateRiskStatus(address user) external;
}

/**
 * @notice This contract acts as a whale account that moves the price of CORN up and down whenever anyone calls it
 */
contract MovePrice {
    CornDEX cornDex;
    ILendingRiskUpdater lending;

    constructor(address _cornDex, address _cornToken, address _lending) {
        cornDex = CornDEX(_cornDex);
        lending = ILendingRiskUpdater(_lending);
        // Approve the cornDEX to use the cornToken
        IERC20(_cornToken).approve(address(cornDex), type(uint256).max);
    }

    function movePrice(int256 size) public {
        if (size > 0) {
            cornDex.swap{ value: uint256(size) }(uint256(size));
        } else {
            cornDex.swap(uint256(-size));
        }
    }

    function movePriceAndUpdateRisk(int256 size, address user) external {
        movePrice(size);
        lending.updateRiskStatus(user);
    }

    receive() external payable {}

    fallback() external payable {}
}
