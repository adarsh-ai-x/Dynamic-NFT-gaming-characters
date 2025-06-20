// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Dynamic NFT Gaming Characters
 * @dev ERC721 token with dynamic character stats and leveling system
 */
contract Project is ERC721, ERC721URIStorage, Ownable {
    
    uint256 private _tokenIdCounter;
    
    // Character stats structure
    struct Character {
        string name;
        uint256 level;
        uint256 experience;
        uint256 strength;
        uint256 agility;
        uint256 intelligence;
        uint256 health;
        uint256 mana;
        uint256 lastBattleTime;
        bool isActive;
    }
    
    // Mapping from token ID to character data
    mapping(uint256 => Character) public characters;
    
    // Experience required for each level
    mapping(uint256 => uint256) public levelRequirements;
    
    // Events
    event CharacterMinted(uint256 indexed tokenId, address indexed owner, string name);
    event CharacterLevelUp(uint256 indexed tokenId, uint256 newLevel);
    event StatsUpdated(uint256 indexed tokenId, uint256 strength, uint256 agility, uint256 intelligence);
    event BattleCompleted(uint256 indexed tokenId, uint256 experienceGained);
    
    constructor(address initialOwner) ERC721("Dynamic Gaming Characters", "DGC") Ownable(initialOwner) {
        // Initialize level requirements
        levelRequirements[1] = 0;
        levelRequirements[2] = 100;
        levelRequirements[3] = 250;
        levelRequirements[4] = 450;
        levelRequirements[5] = 700;
        levelRequirements[10] = 2500;
        levelRequirements[20] = 10000;
        levelRequirements[50] = 100000;
    }
    
    /**
     * @dev Core Function 1: Mint a new gaming character NFT
     * @param to Address to mint the NFT to
     * @param name Character name
     * @param initialStats Array of initial stats [strength, agility, intelligence]
     */
    function mintCharacter(
        address to,
        string memory name,
        uint256[3] memory initialStats
    ) public onlyOwner returns (uint256) {
        require(bytes(name).length > 0, "Character name cannot be empty");
        require(initialStats[0] >= 10 && initialStats[0] <= 100, "Invalid strength value");
        require(initialStats[1] >= 10 && initialStats[1] <= 100, "Invalid agility value");
        require(initialStats[2] >= 10 && initialStats[2] <= 100, "Invalid intelligence value");
        
        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter++;
        
        // Create character with initial stats
        characters[tokenId] = Character({
            name: name,
            level: 1,
            experience: 0,
            strength: initialStats[0],
            agility: initialStats[1],
            intelligence: initialStats[2],
            health: 100 + (initialStats[0] * 2), // Health based on strength
            mana: 50 + (initialStats[2] * 2),   // Mana based on intelligence
            lastBattleTime: block.timestamp,
            isActive: true
        });
        
        _safeMint(to, tokenId);
        
        emit CharacterMinted(tokenId, to, name);
        return tokenId;
    }
    
    /**
     * @dev Core Function 2: Update character stats after gameplay/battles
     * @param tokenId Token ID of the character
     * @param experienceGained Amount of experience gained
     * @param statBonus Additional stat bonuses [strength, agility, intelligence]
     */
    function updateCharacterStats(
        uint256 tokenId,
        uint256 experienceGained,
        uint256[3] memory statBonus
    ) public {
        require(_ownerOf(tokenId) != address(0), "Character does not exist");
        require(ownerOf(tokenId) == msg.sender || owner() == msg.sender, "Not authorized");
        require(characters[tokenId].isActive, "Character is not active");
        
        Character storage character = characters[tokenId];
        
        // Update experience
        character.experience += experienceGained;
        
        // Check for level up
        uint256 newLevel = calculateLevel(character.experience);
        if (newLevel > character.level) {
            character.level = newLevel;
            
            // Bonus stats on level up
            character.strength += 2 + (newLevel / 5);
            character.agility += 2 + (newLevel / 5);
            character.intelligence += 2 + (newLevel / 5);
            character.health += 10 + (newLevel * 2);
            character.mana += 5 + (newLevel * 2);
            
            emit CharacterLevelUp(tokenId, newLevel);
        }
        
        // Apply additional stat bonuses
        character.strength += statBonus[0];
        character.agility += statBonus[1];
        character.intelligence += statBonus[2];
        
        // Update last battle time
        character.lastBattleTime = block.timestamp;
        
        emit StatsUpdated(tokenId, character.strength, character.agility, character.intelligence);
        emit BattleCompleted(tokenId, experienceGained);
    }
    
    /**
     * @dev Core Function 3: Battle system - characters can engage in battles
     * @param attackerTokenId Token ID of attacking character
     * @param defenderTokenId Token ID of defending character
     */
    function engageBattle(uint256 attackerTokenId, uint256 defenderTokenId) 
        public 
        returns (bool attackerWins, uint256 experienceGained) 
    {
        require(_ownerOf(attackerTokenId) != address(0) && _ownerOf(defenderTokenId) != address(0), "One or both characters don't exist");
        require(ownerOf(attackerTokenId) == msg.sender, "Not the owner of attacking character");
        require(attackerTokenId != defenderTokenId, "Cannot battle yourself");
        require(characters[attackerTokenId].isActive && characters[defenderTokenId].isActive, "One or both characters inactive");
        
        Character storage attacker = characters[attackerTokenId];
        Character storage defender = characters[defenderTokenId];
        
        // Battle cooldown check (1 hour)
        require(block.timestamp >= attacker.lastBattleTime + 3600, "Battle cooldown not met");
        
        // Calculate battle power
        uint256 attackerPower = calculateBattlePower(attackerTokenId);
        uint256 defenderPower = calculateBattlePower(defenderTokenId);
        
        // Add some randomness (simplified)
        uint256 randomFactor = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender))) % 20;
        attackerPower += randomFactor;
        
        // Determine winner
        attackerWins = attackerPower > defenderPower;
        
        if (attackerWins) {
            experienceGained = 50 + (defender.level * 10);
            attacker.experience += experienceGained;
            
            // Small experience gain for defender too
            defender.experience += 10;
        } else {
            experienceGained = 20 + (defender.level * 5);
            attacker.experience += experienceGained;
            
            // Winner gets more experience
            defender.experience += 30 + (attacker.level * 8);
        }
        
        // Update battle times
        attacker.lastBattleTime = block.timestamp;
        defender.lastBattleTime = block.timestamp;
        
        // Check for level ups
        checkAndProcessLevelUp(attackerTokenId);
        checkAndProcessLevelUp(defenderTokenId);
        
        emit BattleCompleted(attackerTokenId, experienceGained);
        
        return (attackerWins, experienceGained);
    }
    
    /**
     * @dev Calculate character's battle power
     */
    function calculateBattlePower(uint256 tokenId) public view returns (uint256) {
        require(_ownerOf(tokenId) != address(0), "Character does not exist");
        Character memory character = characters[tokenId];
        return (character.strength * 2) + character.agility + (character.intelligence / 2) + (character.level * 10);
    }
    
    /**
     * @dev Calculate level based on experience
     */
    function calculateLevel(uint256 experience) public view returns (uint256) {
        if (experience >= levelRequirements[50]) return 50;
        if (experience >= levelRequirements[20]) return 20;
        if (experience >= levelRequirements[10]) return 10;
        if (experience >= levelRequirements[5]) return 5;
        if (experience >= levelRequirements[4]) return 4;
        if (experience >= levelRequirements[3]) return 3;
        if (experience >= levelRequirements[2]) return 2;
        return 1;
    }
    
    /**
     * @dev Internal function to check and process level up
     */
    function checkAndProcessLevelUp(uint256 tokenId) internal {
        Character storage character = characters[tokenId];
        uint256 newLevel = calculateLevel(character.experience);
        
        if (newLevel > character.level) {
            character.level = newLevel;
            
            // Level up bonuses
            character.strength += 2 + (newLevel / 5);
            character.agility += 2 + (newLevel / 5);
            character.intelligence += 2 + (newLevel / 5);
            character.health += 10 + (newLevel * 2);
            character.mana += 5 + (newLevel * 2);
            
            emit CharacterLevelUp(tokenId, newLevel);
        }
    }
    
    /**
     * @dev Get character details
     */
    function getCharacter(uint256 tokenId) public view returns (Character memory) {
        require(_ownerOf(tokenId) != address(0), "Character does not exist");
        return characters[tokenId];
    }
    
    /**
     * @dev Toggle character active status
     */
    function toggleCharacterStatus(uint256 tokenId) public {
        require(_ownerOf(tokenId) != address(0), "Character does not exist");
        require(ownerOf(tokenId) == msg.sender, "Not the owner");
        
        characters[tokenId].isActive = !characters[tokenId].isActive;
    }
    
    /**
     * @dev Set level requirements (owner only)
     */
    function setLevelRequirement(uint256 level, uint256 experience) public onlyOwner {
        levelRequirements[level] = experience;
    }
    
    /**
     * @dev Get total number of characters minted
     */
    function totalSupply() public view returns (uint256) {
        return _tokenIdCounter;
    }
    
    /**
     * @dev Check if character can battle (cooldown check)
     */
    function canBattle(uint256 tokenId) public view returns (bool) {
        require(_ownerOf(tokenId) != address(0), "Character does not exist");
        return block.timestamp >= characters[tokenId].lastBattleTime + 3600;
    }
    
    /**
     * @dev Get time remaining until character can battle again
     */
    function getBattleCooldown(uint256 tokenId) public view returns (uint256) {
        require(_ownerOf(tokenId) != address(0), "Character does not exist");
        uint256 nextBattleTime = characters[tokenId].lastBattleTime + 3600;
        if (block.timestamp >= nextBattleTime) {
            return 0;
        }
        return nextBattleTime - block.timestamp;
    }
    
    /**
     * @dev Burn a character NFT and clean up data
     */
    function burnCharacter(uint256 tokenId) public {
        require(ownerOf(tokenId) == msg.sender || owner() == msg.sender, "Not authorized to burn");
        delete characters[tokenId];
        _burn(tokenId);
    }
    
    // Override required functions
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }
    
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
