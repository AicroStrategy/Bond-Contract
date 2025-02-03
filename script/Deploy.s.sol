// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {MintableERC20} from "../src/MintableERC20.sol";
import {BondFactory} from "../src/BondFactory.sol";

import {CREATE2Helper} from "../src/lib/CREATE2Helper.sol";

contract DeployFactoryAndMintableERC20 is Script {
    address public constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address owner = vm.addr(deployerPrivateKey);

        BondFactory factory = new BondFactory(owner);

        console2.log("Bond factory deployed at", address(factory));

        string memory name = "AicroStrategy";
        string memory symbol = "AiSTR";
        uint8 decimals = 18;
        uint256 initialSupply = 1100000000000000000000000000;

        bytes memory constructorArgs = abi.encode(name, symbol, decimals, initialSupply, address(this), owner);

        (bytes32 salt,) = CREATE2Helper.generateSalt(
            address(this),
            constructorArgs,
            type(MintableERC20).creationCode,
            USDC,
            false // we want address < USDC
        );

        address token =
            address(new MintableERC20{salt: salt}(name, symbol, decimals, initialSupply, address(this), owner));
        console2.log("MintableERC20 deployed at:", token);

        vm.stopBroadcast();
    }
}
