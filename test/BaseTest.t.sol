// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {console2} from "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {BondFactory} from "../src/BondFactory.sol";
import {Bond} from "../src/Bond.sol";
import {MintableERC20} from "../src/MintableERC20.sol";
import {TickMath} from "../src/lib/external/TickMath.sol";
import {CREATE2Helper} from "../src/lib/CREATE2Helper.sol";
import {
    IUniswapSwapRouter,
    IUniswapV3Factory,
    INonfungiblePositionManager,
    IUniswapV3Pool
} from "../src/interfaces/IUniswap.sol";

contract BaseTest is Test {
    // Contracts
    BondFactory public factory;
    MintableERC20 public assetToken;
    Bond public bond;

    // Actors
    address public owner;
    address public user;
    address public liquidityProvider;
    address public swapper;

    // Constants - Base Mainnet Addresses
    address public constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address public constant USDC_WHALE = 0x0B0A5886664376F59C351ba3f598C8A8B4D0A6f3;
    address public constant NONFUNGIBLE_POSITION_MANAGER = 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1;
    address public constant SWAP_ROUTER = 0x2626664c2603336E57B271c5C0b26F421741e481;
    address public constant FACTORY = 0x33128a8fC17869897dcE68Ed026d694621f6FDfD;

    // Uniswap Interfaces
    IUniswapV3Factory public uniswapFactory;
    IUniswapSwapRouter public uniswapRouter;
    INonfungiblePositionManager public nonfungiblePositionManager;
    IUniswapV3Pool public assetUsdcPool;

    // Bond Default Parameters
    string public BOND_NAME = "Test Bond";
    string public BOND_SYMBOL = "TBOND";
    uint8 public BOND_DECIMALS = 18;
    int24 public STARTING_TICK = -276200;
    int24 public ACTUAL_TICK = -276310;
    uint160 public SQRT_STRIKE_PRICE_X96;
    uint256 public MAX_USDC = 1000000e6;

    // Asset Token Default Parameters
    string public ASSET_NAME = "Asset Token";
    string public ASSET_SYMBOL = "AT";
    uint8 public ASSET_DECIMALS = 18;
    uint256 public ASSET_SUPPLY = 10000000e18;

    function setUp() public virtual {
        // Fork Base mainnet
        vm.createSelectFork(vm.envString("RPC_URL"));

        owner = makeAddr("owner");
        user = makeAddr("user");
        liquidityProvider = makeAddr("liquidityProvider");
        swapper = makeAddr("swapper");
        // Setup Uniswap interfaces
        uniswapFactory = IUniswapV3Factory(FACTORY);
        uniswapRouter = IUniswapSwapRouter(SWAP_ROUTER);
        nonfungiblePositionManager = INonfungiblePositionManager(NONFUNGIBLE_POSITION_MANAGER);

        SQRT_STRIKE_PRICE_X96 = TickMath.getSqrtRatioAtTick(ACTUAL_TICK);

        // Deploy contracts
        vm.startPrank(owner);

        // Deploy bond factory
        factory = new BondFactory(owner);

        // Deploy asset token
        bytes memory constructorArgs =
            abi.encode(ASSET_NAME, ASSET_SYMBOL, ASSET_DECIMALS, ASSET_SUPPLY, address(factory), owner);
        bytes memory creationCode = type(MintableERC20).creationCode;
        (bytes32 salt,) = CREATE2Helper.generateSalt(owner, constructorArgs, creationCode, USDC, false);
        assetToken = new MintableERC20{salt: salt}(
            ASSET_NAME, ASSET_SYMBOL, ASSET_DECIMALS, ASSET_SUPPLY, address(factory), owner
        );
        assetUsdcPool = IUniswapV3Pool(
            nonfungiblePositionManager.createAndInitializePoolIfNecessary(
                address(assetToken), USDC, 10000, SQRT_STRIKE_PRICE_X96
            )
        );
        factory.setAssetToken(address(assetToken));

        // Deploy bond
        bond = Bond(
            factory.createBondProgram(
                BOND_NAME,
                BOND_SYMBOL,
                BOND_DECIMALS,
                SQRT_STRIKE_PRICE_X96,
                MAX_USDC,
                block.timestamp + 7 days, // issuanceEnd
                block.timestamp + 14 days // bondExpiry
            )
        );
        vm.stopPrank();

        // Fund test accounts with USDC
        vm.startPrank(USDC_WHALE);
        IERC20(USDC).transfer(user, 10000e6);
        IERC20(USDC).transfer(liquidityProvider, 10000e6);
        IERC20(USDC).transfer(swapper, 10000e6);
        vm.stopPrank();

        vm.startPrank(owner);
        assetToken.transfer(liquidityProvider, 1000000e18);
        vm.stopPrank();

        // add liquidity to pool
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: address(assetToken),
            token1: USDC,
            fee: 10000,
            tickLower: -276200 - 2000,
            tickUpper: -276200 + 2000,
            amount0Desired: 100000e18,
            amount1Desired: 1000e6,
            amount0Min: 0,
            amount1Min: 0,
            recipient: liquidityProvider,
            deadline: block.timestamp + 1000000
        });

        vm.startPrank(liquidityProvider);
        // approve asset and usdc to nonfungiblePositionManager
        assetToken.approve(address(nonfungiblePositionManager), 100000e18);
        IERC20(USDC).approve(address(nonfungiblePositionManager), 1000e6);
        nonfungiblePositionManager.mint(params);
        vm.stopPrank();
    }

    // Helper function to create a new bond with custom parameters
    function createBond(
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint160 sqrtStrikePriceX96,
        uint256 maxUsdc,
        uint256 issuanceEnd,
        uint256 bondExpiry
    ) internal returns (Bond) {
        vm.prank(owner);
        return Bond(
            factory.createBondProgram(name, symbol, decimals, sqrtStrikePriceX96, maxUsdc, issuanceEnd, bondExpiry)
        );
    }

    // Helper to move time forward
    function timeTravel(uint256 seconds_) internal {
        vm.warp(block.timestamp + seconds_);
    }
}
