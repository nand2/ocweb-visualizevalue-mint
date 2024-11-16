export const abi = [
  {
    inputs: [
      {
        internalType: "contract IDecentralizedApp",
        name: "_frontend",
        type: "address"
      },
      {
        internalType: "contract IVersionableWebsitePlugin",
        name: "_staticFrontendPlugin",
        type: "address"
      },
      {
        internalType: "contract IVersionableWebsitePlugin",
        name: "_ocWebAdminPlugin",
        type: "address"
      }
    ],
    stateMutability: "nonpayable",
    type: "constructor"
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "owner",
        type: "address"
      }
    ],
    name: "OwnableInvalidOwner",
    type: "error"
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "account",
        type: "address"
      }
    ],
    name: "OwnableUnauthorizedAccount",
    type: "error"
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "value",
        type: "uint256"
      },
      {
        internalType: "uint256",
        name: "length",
        type: "uint256"
      }
    ],
    name: "StringsInsufficientHexLength",
    type: "error"
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "previousOwner",
        type: "address"
      },
      {
        indexed: true,
        internalType: "address",
        name: "newOwner",
        type: "address"
      }
    ],
    name: "OwnershipTransferStarted",
    type: "event"
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "previousOwner",
        type: "address"
      },
      {
        indexed: true,
        internalType: "address",
        name: "newOwner",
        type: "address"
      }
    ],
    name: "OwnershipTransferred",
    type: "event"
  },
  {
    inputs: [],
    name: "acceptOwnership",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function"
  },
  {
    inputs: [
      {
        internalType: "string",
        name: "name",
        type: "string"
      },
      {
        internalType: "contract IDecentralizedApp",
        name: "fileServer",
        type: "address"
      }
    ],
    name: "addTheme",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function"
  },
  {
    inputs: [
      {
        internalType: "contract IVersionableWebsite",
        name: "website",
        type: "address"
      },
      {
        internalType: "uint256",
        name: "fromFrontendIndex",
        type: "uint256"
      },
      {
        internalType: "uint256",
        name: "toFrontendIndex",
        type: "uint256"
      }
    ],
    name: "copyFrontendSettings",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function"
  },
  {
    inputs: [],
    name: "frontend",
    outputs: [
      {
        internalType: "contract IDecentralizedApp",
        name: "",
        type: "address"
      }
    ],
    stateMutability: "view",
    type: "function"
  },
  {
    inputs: [
      {
        internalType: "contract IVersionableWebsite",
        name: "website",
        type: "address"
      },
      {
        internalType: "uint256",
        name: "websiteVersionIndex",
        type: "uint256"
      }
    ],
    name: "getConfig",
    outputs: [
      {
        components: [
          {
            internalType: "string[]",
            name: "rootPath",
            type: "string[]"
          },
          {
            internalType: "contract IDecentralizedApp",
            name: "theme",
            type: "address"
          }
        ],
        internalType: "struct VisualizeValueMintPlugin.Config",
        name: "",
        type: "tuple"
      }
    ],
    stateMutability: "view",
    type: "function"
  },
  {
    inputs: [],
    name: "infos",
    outputs: [
      {
        components: [
          {
            internalType: "string",
            name: "name",
            type: "string"
          },
          {
            internalType: "string",
            name: "version",
            type: "string"
          },
          {
            internalType: "string",
            name: "title",
            type: "string"
          },
          {
            internalType: "string",
            name: "subTitle",
            type: "string"
          },
          {
            internalType: "string",
            name: "author",
            type: "string"
          },
          {
            internalType: "string",
            name: "homepage",
            type: "string"
          },
          {
            internalType: "contract IVersionableWebsitePlugin[]",
            name: "dependencies",
            type: "address[]"
          },
          {
            components: [
              {
                internalType: "string",
                name: "title",
                type: "string"
              },
              {
                internalType: "string",
                name: "url",
                type: "string"
              },
              {
                internalType: "contract IVersionableWebsitePlugin",
                name: "moduleForGlobalAdminPanel",
                type: "address"
              },
              {
                internalType: "enum IVersionableWebsitePlugin.AdminPanelType",
                name: "panelType",
                type: "uint8"
              }
            ],
            internalType: "struct IVersionableWebsitePlugin.AdminPanel[]",
            name: "adminPanels",
            type: "tuple[]"
          }
        ],
        internalType: "struct IVersionableWebsitePlugin.Infos",
        name: "",
        type: "tuple"
      }
    ],
    stateMutability: "view",
    type: "function"
  },
  {
    inputs: [],
    name: "ocWebAdminPlugin",
    outputs: [
      {
        internalType: "contract IVersionableWebsitePlugin",
        name: "",
        type: "address"
      }
    ],
    stateMutability: "view",
    type: "function"
  },
  {
    inputs: [],
    name: "owner",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address"
      }
    ],
    stateMutability: "view",
    type: "function"
  },
  {
    inputs: [],
    name: "pendingOwner",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address"
      }
    ],
    stateMutability: "view",
    type: "function"
  },
  {
    inputs: [
      {
        internalType: "contract IVersionableWebsite",
        name: "website",
        type: "address"
      },
      {
        internalType: "uint256",
        name: "websiteVersionIndex",
        type: "uint256"
      },
      {
        internalType: "string[]",
        name: "resource",
        type: "string[]"
      },
      {
        components: [
          {
            internalType: "string",
            name: "key",
            type: "string"
          },
          {
            internalType: "string",
            name: "value",
            type: "string"
          }
        ],
        internalType: "struct KeyValue[]",
        name: "params",
        type: "tuple[]"
      }
    ],
    name: "processWeb3Request",
    outputs: [
      {
        internalType: "uint256",
        name: "statusCode",
        type: "uint256"
      },
      {
        internalType: "string",
        name: "body",
        type: "string"
      },
      {
        components: [
          {
            internalType: "string",
            name: "key",
            type: "string"
          },
          {
            internalType: "string",
            name: "value",
            type: "string"
          }
        ],
        internalType: "struct KeyValue[]",
        name: "headers",
        type: "tuple[]"
      }
    ],
    stateMutability: "view",
    type: "function"
  },
  {
    inputs: [],
    name: "renounceOwnership",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function"
  },
  {
    inputs: [
      {
        internalType: "contract IVersionableWebsite",
        name: "website",
        type: "address"
      },
      {
        internalType: "uint256",
        name: "websiteVersionIndex",
        type: "uint256"
      },
      {
        internalType: "string[]",
        name: "resource",
        type: "string[]"
      },
      {
        components: [
          {
            internalType: "string",
            name: "key",
            type: "string"
          },
          {
            internalType: "string",
            name: "value",
            type: "string"
          }
        ],
        internalType: "struct KeyValue[]",
        name: "params",
        type: "tuple[]"
      }
    ],
    name: "rewriteWeb3Request",
    outputs: [
      {
        internalType: "bool",
        name: "rewritten",
        type: "bool"
      },
      {
        internalType: "string[]",
        name: "newResource",
        type: "string[]"
      },
      {
        components: [
          {
            internalType: "string",
            name: "key",
            type: "string"
          },
          {
            internalType: "string",
            name: "value",
            type: "string"
          }
        ],
        internalType: "struct KeyValue[]",
        name: "newParams",
        type: "tuple[]"
      }
    ],
    stateMutability: "view",
    type: "function"
  },
  {
    inputs: [
      {
        internalType: "contract IVersionableWebsite",
        name: "website",
        type: "address"
      },
      {
        internalType: "uint256",
        name: "websiteVersionIndex",
        type: "uint256"
      },
      {
        components: [
          {
            internalType: "string[]",
            name: "rootPath",
            type: "string[]"
          },
          {
            internalType: "contract IDecentralizedApp",
            name: "theme",
            type: "address"
          }
        ],
        internalType: "struct VisualizeValueMintPlugin.Config",
        name: "_config",
        type: "tuple"
      }
    ],
    name: "setConfig",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function"
  },
  {
    inputs: [
      {
        components: [
          {
            internalType: "string",
            name: "name",
            type: "string"
          },
          {
            internalType: "contract IDecentralizedApp",
            name: "fileServer",
            type: "address"
          }
        ],
        internalType: "struct VisualizeValueMintPlugin.Theme[]",
        name: "_themes",
        type: "tuple[]"
      }
    ],
    name: "setThemes",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function"
  },
  {
    inputs: [],
    name: "staticFrontendPlugin",
    outputs: [
      {
        internalType: "contract IVersionableWebsitePlugin",
        name: "",
        type: "address"
      }
    ],
    stateMutability: "view",
    type: "function"
  },
  {
    inputs: [
      {
        internalType: "bytes4",
        name: "interfaceId",
        type: "bytes4"
      }
    ],
    name: "supportsInterface",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool"
      }
    ],
    stateMutability: "view",
    type: "function"
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256"
      }
    ],
    name: "themes",
    outputs: [
      {
        internalType: "string",
        name: "name",
        type: "string"
      },
      {
        internalType: "contract IDecentralizedApp",
        name: "fileServer",
        type: "address"
      }
    ],
    stateMutability: "view",
    type: "function"
  },
  {
    name: "getThemes",
    outputs: [
      {
        components: [
          {
            internalType: "string",
            name: "name",
            type: "string"
          },
          {
            internalType: "contract IDecentralizedApp",
            name: "fileServer",
            type: "address"
          }
        ],
        internalType: "struct VisualizeValueMintPlugin.Theme[]",
        name: "",
        type: "tuple[]"
      }
    ],
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "newOwner",
        type: "address"
      }
    ],
    name: "transferOwnership",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function"
  }
];