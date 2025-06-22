// SPDX-License-Identifier: MIT
// Remix IDE Deployment Script for Dynamic NFT Gaming Characters

const hre = require("hardhat");

async function main() {
    console.log("🚀 Starting deployment of Dynamic NFT Gaming Characters...");
    
    // Get the deployer account
    const [deployer] = await hre.ethers.getSigners();
    console.log("📝 Deploying contracts with account:", deployer.address);
    
    // Check deployer balance
    const balance = await hre.ethers.provider.getBalance(deployer.address);
    console.log("💰 Account balance:", hre.ethers.formatEther(balance), "ETH");
    
    // Deploy the contract
    console.log("\n📦 Deploying Project contract...");
    
    const Project = await hre.ethers.getContractFactory("Project");
    const project = await Project.deploy(deployer.address);
    
    // Wait for deployment
    await project.waitForDeployment();
    const contractAddress = await project.getAddress();
    
    console.log("✅ Project contract deployed to:", contractAddress);
    console.log("🔗 Transaction hash:", project.deploymentTransaction().hash);
    
    // Verify deployment by calling some view functions
    console.log("\n🔍 Verifying deployment...");
    
    try {
        const name = await project.name();
        const symbol = await project.symbol();
        const owner = await project.owner();
        const totalSupply = await project.totalSupply();
        
        console.log("📋 Contract Details:");
        console.log("   Name:", name);
        console.log("   Symbol:", symbol);
        console.log("   Owner:", owner);
        console.log("   Total Supply:", totalSupply.toString());
        
        // Test level requirements
        const level2Req = await project.levelRequirements(2);
        const level5Req = await project.levelRequirements(5);
        console.log("   Level 2 requirement:", level2Req.toString(), "XP");
        console.log("   Level 5 requirement:", level5Req.toString(), "XP");
        
    } catch (error) {
        console.error("❌ Error verifying deployment:", error.message);
    }
    
    // Optional: Mint a test character if deployer wants to
    console.log("\n🎮 Would you like to mint a test character? (Uncomment the code below)");
    
    /*
    console.log("🎨 Minting test character...");
    try {
        const testCharacterTx = await project.mintCharacter(
            deployer.address,
            "Test Warrior",
            [50, 40, 30] // [strength, agility, intelligence]
        );
        
        await testCharacterTx.wait();
        console.log("✅ Test character minted! Transaction:", testCharacterTx.hash);
        
        // Get the character details
        const character = await project.getCharacter(0);
        console.log("🏆 Character Details:");
        console.log("   Name:", character.name);
        console.log("   Level:", character.level.toString());
        console.log("   Strength:", character.strength.toString());
        console.log("   Agility:", character.agility.toString());
        console.log("   Intelligence:", character.intelligence.toString());
        console.log("   Health:", character.health.toString());
        console.log("   Mana:", character.mana.toString());
        
    } catch (error) {
        console.error("❌ Error minting test character:", error.message);
    }
    */
    
    console.log("\n📊 Deployment Summary:");
    console.log("=====================================");
    console.log("Contract Address:", contractAddress);
    console.log("Deployer Address:", deployer.address);
    console.log("Network:", hre.network.name);
    console.log("Gas Used: Check transaction receipt");
    console.log("=====================================");
    
    // Save deployment info to a file (optional)
    const deploymentInfo = {
        contractAddress: contractAddress,
        deployerAddress: deployer.address,
        network: hre.network.name,
        deploymentTime: new Date().toISOString(),
        transactionHash: project.deploymentTransaction().hash
    };
    
    console.log("\n💾 Deployment Info (save this):");
    console.log(JSON.stringify(deploymentInfo, null, 2));
    
    return contractAddress;
}

// For Remix IDE compatibility
if (typeof module !== 'undefined' && module.exports) {
    module.exports = main;
}

// Run the deployment if this script is executed directly
main()
    .then((contractAddress) => {
        console.log("\n🎉 Deployment completed successfully!");
        console.log("Contract Address:", contractAddress);
        process.exit(0);
    })
    .catch((error) => {
        console.error("💥 Deployment failed:", error);
        process.exit(1);
    });

// Additional utility functions for post-deployment testing

/**
 * Test function to demonstrate minting characters
 */
async function testMintCharacter(contractAddress, characterName, stats) {
    const [deployer] = await hre.ethers.getSigners();
    const Project = await hre.ethers.getContractAt("Project", contractAddress);
    
    console.log(`🎨 Minting character: ${characterName}...`);
    
    const tx = await Project.mintCharacter(
        deployer.address,
        characterName,
        stats
    );
    
    await tx.wait();
    console.log("✅ Character minted! Transaction:", tx.hash);
    
    // Get the latest token ID
    const totalSupply = await Project.totalSupply();
    const tokenId = totalSupply - 1n;
    
    const character = await Project.getCharacter(tokenId);
    console.log("Character Details:", {
        name: character.name,
        level: character.level.toString(),
        strength: character.strength.toString(),
        agility: character.agility.toString(),
        intelligence: character.intelligence.toString(),
        health: character.health.toString(),
        mana: character.mana.toString()
    });
    
    return tokenId;
}

/**
 * Test function to demonstrate battle system
 */
async function testBattle(contractAddress, attackerTokenId, defenderTokenId) {
    const [deployer] = await hre.ethers.getSigners();
    const Project = await hre.ethers.getContractAt("Project", contractAddress);
    
    console.log(`⚔️ Starting battle between character ${attackerTokenId} and ${defenderTokenId}...`);
    
    // Check if attacker can battle
    const canBattle = await Project.canBattle(attackerTokenId);
    if (!canBattle) {
        const cooldown = await Project.getBattleCooldown(attackerTokenId);
        console.log(`❌ Character ${attackerTokenId} is on cooldown for ${cooldown} seconds`);
        return;
    }
    
    // Get battle powers
    const attackerPower = await Project.calculateBattlePower(attackerTokenId);
    const defenderPower = await Project.calculateBattlePower(defenderTokenId);
    
    console.log(`⚡ Attacker Power: ${attackerPower}`);
    console.log(`🛡️ Defender Power: ${defenderPower}`);
    
    // Engage battle
    const tx = await Project.engageBattle(attackerTokenId, defenderTokenId);
    const receipt = await tx.wait();
    
    console.log("⚔️ Battle completed! Transaction:", tx.hash);
    
    // Parse battle results from events
    const battleEvent = receipt.logs.find(log => {
        try {
            return Project.interface.parseLog(log).name === 'BattleCompleted';
        } catch {
            return false;
        }
    });
    
    if (battleEvent) {
        const parsedEvent = Project.interface.parseLog(battleEvent);
        console.log(`🏆 Experience gained: ${parsedEvent.args.experienceGained}`);
    }
    
    return tx.hash;
}

// Export utility functions for Remix IDE
if (typeof window !== 'undefined') {
    window.testMintCharacter = testMintCharacter;
    window.testBattle = testBattle;
}
