const hre = require("hardhat");

const { ethers } = hre;

const { utils: { solidityPack, solidityKeccak256 } } = ethers;

console.log(solidityKeccak256(
    ['bytes'],
    [solidityPack(
        ['uint8[]', 'string'],
        [[1, 2, 3, 4], 'password'])
    ]));