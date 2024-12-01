// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Script, console } from "forge-std/Script.sol";

// VV Mint
import { Renderer } from "lib/mint/contracts/contracts/renderers/Renderer.sol";
import { Mint } from "lib/mint/contracts/contracts/Mint.sol";
import { FactoryV1 } from "lib/mint/contracts/contracts/factories/FactoryV1.sol";
import { Factory } from "lib/mint/contracts/contracts/Factory.sol";


contract DeployVVMintScript is Script {
    

    function setUp() public {}

    function run() public {

        vm.startBroadcast();


        Renderer renderer = new Renderer();
        Mint mint = new Mint();
        FactoryV1 factoryV1 = new FactoryV1();
        Factory factory = new Factory(address(factoryV1), address(mint), address(renderer));

        console.log("Renderer: ", address(renderer));
        console.log("Mint: ", address(mint));
        console.log("FactoryV1: ", address(factoryV1));
        console.log("Factory: ", address(factory));

        vm.stopBroadcast();
    }

}
