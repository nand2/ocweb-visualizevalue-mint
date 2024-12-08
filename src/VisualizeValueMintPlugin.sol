// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";

import "ocweb/contracts/src/interfaces/IVersionableWebsite.sol";
import "ocweb/contracts/src/interfaces/IDecentralizedApp.sol";
import "./library/LibStrings.sol";

contract VisualizeValueMintPlugin is ERC165, IVersionableWebsitePlugin, Ownable2Step {
    // Main frontend: where the admin JS/CSS are located, for the admin panel
    IDecentralizedApp public frontend;
    // Addresses of plugin dependencies
    IVersionableWebsitePlugin public staticFrontendPlugin;
    IVersionableWebsitePlugin public ocWebAdminPlugin;

    // List of available themes (managed by owner of the plugin)
    struct Theme {
        string name;
        // The resourceRequest web3:// website serving the files of the theme
        IDecentralizedApp fileServer;
    }
    Theme[] public themes;

    // Config of IVersionableWebsite (OCWebsite) / website version index
    struct Config {
        string[] rootPath;
        // The resourceRequest web3:// website serving the files of the theme
        IDecentralizedApp theme;
    }
    mapping(IVersionableWebsite => mapping(uint => Config)) private configs;

    constructor(IDecentralizedApp _frontend, IVersionableWebsitePlugin _staticFrontendPlugin, IVersionableWebsitePlugin _ocWebAdminPlugin) Ownable(msg.sender) {
        frontend = _frontend;
        staticFrontendPlugin = _staticFrontendPlugin;
        ocWebAdminPlugin = _ocWebAdminPlugin;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC165) returns (bool) {
        return
            interfaceId == type(IVersionableWebsitePlugin).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function infos() external view returns (Infos memory) {
        IVersionableWebsitePlugin[] memory dependencies = new IVersionableWebsitePlugin[](2);
        dependencies[0] = staticFrontendPlugin;
        dependencies[1] = ocWebAdminPlugin;

        AdminPanel[] memory adminPanels = new AdminPanel[](3);
        adminPanels[0] = AdminPanel({
            title: "VV artist platform",
            url: "/plugins/visualizevalue-mint/admin.umd.js",
            moduleForGlobalAdminPanel: ocWebAdminPlugin,
            panelType: AdminPanelType.Primary
        });
        adminPanels[1] = AdminPanel({
            title: "Settings",
            url: "/plugins/visualizevalue-mint/admin.umd.js",
            moduleForGlobalAdminPanel: ocWebAdminPlugin,
            panelType: AdminPanelType.Secondary
        });
        adminPanels[2] = AdminPanel({
            title: "Settings 2",
            url: "/plugins/visualizevalue-mint/admin.umd.js",
            moduleForGlobalAdminPanel: ocWebAdminPlugin,
            panelType: AdminPanelType.Secondary
        });

        return
            Infos({
                name: "visualizeValueMint",
                version: "0.1.1",
                title: "VV Mint Artist Platform",
                subTitle: "Create and show your 24h open edition NFTs with the VV Mint Artist Platform",
                author: "Jalil (contracts && frontend) / Nand (plugin)",
                homepage: "https://mint.vv.xyz/",
                dependencies: dependencies,
                adminPanels: adminPanels
            });
    }

    /**
     * Internal redirects for the frontend serving
     */
    function rewriteWeb3Request(IVersionableWebsite website, uint websiteVersionIndex, string[] memory resource, KeyValue[] memory params) external view returns (bool rewritten, string[] memory newResource, KeyValue[] memory newParams) {
        return (false, new string[](0), new KeyValue[](0));
    }

    /**
     * Process the web3 request
     */
    function processWeb3Request(
        IVersionableWebsite website,
        uint websiteVersionIndex,
        string[] memory resource,
        KeyValue[] memory params
    )
        external view override returns (uint statusCode, string memory body, KeyValue[] memory headers)
    {
        // Serve the admin parts : /plugins/visualizevalue-mint/* -> /admin/*
        if(resource.length >= 2 && Strings.equal(resource[0], "plugins") && Strings.equal(resource[1], "visualizevalue-mint")) {
            string[] memory newResource = new string[](resource.length - 1);
            newResource[0] = "admin";
            for(uint i = 2; i < resource.length; i++) {
                newResource[i - 1] = resource[i];
            }
            
            (statusCode, body, headers) = frontend.request(newResource, params);

            // ERC-7774
            // If there is a "Cache-control: evm-events" header, we will replace it with 
            // "Cache-control: evm-events=<addressOfFrontend><newResourcePath>"
            // That way, we indicate that the contract emitting the cache clearing events is 
            // the frontend website
            for(uint i = 0; i < headers.length; i++) {
                if(LibStrings.compare(headers[i].key, "Cache-control") && LibStrings.compare(headers[i].value, "evm-events")) {
                    string memory path = "/";
                    for(uint j = 0; j < newResource.length; j++) {
                        path = string.concat(path, newResource[j]);
                        if(j < newResource.length - 1) {
                            path = string.concat(path, "/");
                        }
                    }
                    headers[i].value = string.concat("evm-events=", "\"", LibStrings.toHexString(address(frontend)), path, "\"");
                }
            }

            return (statusCode, body, headers);
        }

        // Serve the frontend : Proxy /[config.rootPath]/* -> /* (at selected theme)
        Config memory config = configs[website][websiteVersionIndex];
        if(resource.length >= config.rootPath.length) {
            bool prefixMatch = true;
            for(uint i = 0; i < config.rootPath.length; i++) {
                if(Strings.equal(resource[i], config.rootPath[i]) == false) {
                    prefixMatch = false;
                    break;
                }
            }

            if(prefixMatch) {
                string[] memory newResource = new string[](resource.length - config.rootPath.length);
                for(uint i = config.rootPath.length; i < resource.length; i++) {
                    newResource[i - config.rootPath.length] = resource[i];
                }

                // Determine which theme we are going to use : 
                // 1. The theme set in the config
                // 2. The first theme available
                IDecentralizedApp theme;
                if(config.theme != IDecentralizedApp(address(0))) {
                    theme = config.theme;
                } else if(themes.length > 0) {
                    theme = themes[0].fileServer;
                }

                // If no theme was determined, return right away
                if(theme == IDecentralizedApp(address(0))) {
                    return (statusCode, body, headers);
                }

                // Fetch the resource from the theme
                (statusCode, body, headers) = theme.request(newResource, params);

                // ERC-7774
                // If there is a "Cache-control: evm-events" header, we will replace it with 
                // "Cache-control: evm-events=<addressOfFrontend><newResourcePath>"
                // That way, we indicate that the contract emitting the cache clearing events is 
                // the frontend website
                for(uint i = 0; i < headers.length; i++) {
                    if(LibStrings.compare(headers[i].key, "Cache-control") && LibStrings.compare(headers[i].value, "evm-events")) {
                        string memory path = "/";
                        for(uint j = 0; j < newResource.length; j++) {
                            path = string.concat(path, newResource[j]);
                            if(j < newResource.length - 1) {
                                path = string.concat(path, "/");
                            }
                        }
                        headers[i].value = string.concat("evm-events=", "\"", LibStrings.toHexString(address(frontend)), path, "\"");
                    }
                }

                return (statusCode, body, headers);
            }
        }
    }

    function copyFrontendSettings(IVersionableWebsite website, uint fromFrontendIndex, uint toFrontendIndex) public {
        require(address(website) == msg.sender);

        Config storage config = configs[website][toFrontendIndex];
        Config storage fromConfig = configs[website][fromFrontendIndex];

        config.rootPath = fromConfig.rootPath;
        config.theme = fromConfig.theme;
    }

    function getConfig(IVersionableWebsite website, uint websiteVersionIndex) external view returns (Config memory) {
        return configs[website][websiteVersionIndex];
    }

    function setConfig(IVersionableWebsite website, uint websiteVersionIndex, Config memory _config) external {
        require(address(website) == msg.sender || website.owner() == msg.sender, "Not the owner");

        require(website.isLocked() == false, "Website is locked");

        require(websiteVersionIndex < website.getWebsiteVersionCount(), "Website version out of bounds");
        IVersionableWebsite.WebsiteVersion memory websiteVersion = website.getWebsiteVersion(websiteVersionIndex);
        require(websiteVersion.locked == false, "Website version is locked");

        // Ensure _config.theme is one of the themes, or zero address
        bool themeFound = false;
        for (uint i = 0; i < themes.length; i++) {
            if (themes[i].fileServer == _config.theme) {
                themeFound = true;
                break;
            }
        }
        require(themeFound || _config.theme == IDecentralizedApp(address(0)), "Theme not found");


        Config storage config = configs[website][websiteVersionIndex];

        config.rootPath = _config.rootPath;
        config.theme = _config.theme;

        // ERC-7774: Send an event to clear all cache
        string[] memory pathsToClear = new string[](1);
        pathsToClear[0] = "*";
        website.clearPathCache(websiteVersionIndex, pathsToClear);
    }

    function addTheme(string memory name, IDecentralizedApp fileServer) external onlyOwner {
        themes.push(Theme({
            name: name,
            fileServer: fileServer
        }));
    }

    function getThemes() external view returns (Theme[] memory) {
        return themes;
    }

    function setThemes(Theme[] memory _themes) external onlyOwner {
        delete themes;
        for (uint i = 0; i < _themes.length; i++) {
            themes.push(_themes[i]);
        }
    }
}