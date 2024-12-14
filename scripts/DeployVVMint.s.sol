// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Script, console } from "forge-std/Script.sol";

// VV Mint
import { Renderer } from "lib/mint/contracts/contracts/renderers/Renderer.sol";
import { AnimationRenderer } from "lib/mint/contracts/contracts/renderers/AnimationRenderer.sol";
import { P5Renderer } from "lib/mint/contracts/contracts/renderers/P5Renderer.sol";
import { P5RendererV2 } from "lib/mint/contracts/contracts/renderers/P5RendererV2.sol";
import { Mint } from "lib/mint/contracts/contracts/Mint.sol";
import { FactoryV1 } from "lib/mint/contracts/contracts/factories/FactoryV1.sol";
import { Factory } from "lib/mint/contracts/contracts/Factory.sol";


contract DeployVVMintScript is Script {
    

    function setUp() public {}

    function run() public {

        vm.startBroadcast();

        // Renderers
        Renderer renderer = new Renderer();
        AnimationRenderer animationRenderer = new AnimationRenderer();
        P5Renderer p5Renderer = new P5Renderer();
        P5RendererV2 p5RendererV2 = new P5RendererV2();

        Mint mint = new Mint();
        FactoryV1 factoryV1 = new FactoryV1();
        Factory factory = new Factory(address(factoryV1), address(mint), address(renderer));


        console.log("Renderer: ", address(renderer));
        console.log("AnimationRenderer: ", address(animationRenderer));
        console.log("P5Renderer: ", address(p5Renderer));
        console.log("P5RendererV2: ", address(p5RendererV2));

        console.log("Mint: ", address(mint));
        console.log("FactoryV1: ", address(factoryV1));
        console.log("Factory: ", address(factory));

        vm.stopBroadcast();
    }

}
