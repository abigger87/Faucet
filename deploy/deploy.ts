// * Import helper functions
const { deployFusePoolFaucets, deployEthPoolFaucets } = require("../scripts/");

// * Import types
import { DeployFunction } from 'hardhat-deploy/types';
import {HardhatRuntimeEnvironment} from 'hardhat/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const inquirer = require('inquirer');
    await inquirer
    .prompt([
        {
            name: "deploy_select",
            type: "list",
            message: "Deploy Faucets for:",
            choices: ["Fuse Pools!", "Eth Pool!"],
        }
    ])
    .then(async answers => {
        if(answers.deploy_select == "Fuse Pools!") {
            await deployFusePoolFaucets({ deployMainnet: false }, hre);
        } else if (answers.deploy_select == "Eth Pool!") {
            await deployEthPoolFaucets({ deployMainnet: false }, hre);
        }
    })
    .catch(error => {
        console.log("ERROR");
        console.warn(error)
    });
};

export default func;