// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ForgeToken} from "./ForgeToken.sol";

/// @title AgentForge
/// @notice NFT game for Agent ID holders (Binance Agent ID Hackathon).
///         Holders of an Agent ID mint Hero NFTs (2 free per wallet, up to
///         10 total with paid mints), merge them up to Lv10, forge Lv10
///         heroes into tiered NFTs, battle each other for BNB + $FORGE, and
///         share an end-of-season pool funded by paid mints and battle fees.
/// @dev Access control is a plain registry check: the caller must hold at
///      least one token of the Agent ID registry. The game never resolves an
///      Agent ID name to a wallet and never looks up anyone else's holdings.
///      Randomness is prevrandao-based pseudo-randomness (no VRF): outcomes
///      are probabilistic, never guaranteed, and the frontend shows the
///      exact win probabilities. The owner has NO power over funds: there is
///      no dev cut, no withdraw function, and the season pool is paid out
///      only through the public claim function.
contract AgentForge is ERC721, Ownable, ReentrancyGuard {
    // ------------------------------------------------------------------------
    // Types
    // ------------------------------------------------------------------------

    enum Tier {
        NONE, // base hero, not yet forged
        UNCOMMON,
        RARE,
        MYTHIC,
        LEGENDARY
    }

    enum BattleStatus {
        OPEN,
        RESOLVED,
        CANCELLED
    }

    struct Hero {
        uint8 level;
        Tier tier;
    }

    struct Battle {
        address creator;
        address challenger;
        uint256 creatorTokenId;
        uint256 challengerTokenId;
        uint256 bet;
        BattleStatus status;
        address winner;
    }

    // ------------------------------------------------------------------------
    // Errors
    // ------------------------------------------------------------------------

    error NoAgentId();
    error FreeMintExhausted();
    error MintCapExceeded();
    error MaxSupplyExceeded();
    error IncorrectPayment(uint256 expected, uint256 actual);
    error NotTokenOwner();
    error TokenInBattle();
    error SameToken();
    error TierCannotMerge();
    error TierCannotForge();
    error MaxLevelReached();
    error NotMaxLevel();
    error InvalidBet();
    error BattleNotFound();
    error BattleNotOpen();
    error SelfBattle();
    error NotBattleCreator();
    error SeasonNotEnded();
    error SeasonAlreadySnapshotted();
    error SeasonNotSnapshotted();
    error AlreadyClaimed();
    error NotTierNft();
    error NoTierWeight();
    error TransferFailed();

    // ------------------------------------------------------------------------
    // Events
    // ------------------------------------------------------------------------

    event Mint(address indexed minter, uint256 indexed tokenId, uint256 level, Tier tier, bool paid);
    event Merge(address indexed owner, uint256 indexed tokenA, uint256 indexed tokenB, uint256 newTokenId, uint256 newLevel);
    event Forge(address indexed owner, uint256 indexed burnedTokenId, uint256 indexed newTokenId, Tier tier);
    event BattleCreated(uint256 indexed battleId, address indexed creator, uint256 indexed tokenId, uint256 bet);
    event BattleResolved(
        uint256 indexed battleId, address indexed winner, address indexed loser, uint256 pot, uint256 winnerShare, uint256 poolShare
    );
    event BattleCancelled(uint256 indexed battleId, address indexed creator);
    event SeasonSnapshot(uint256 indexed snapshotPool, uint256 totalWeight);
    event SeasonRewardClaimed(address indexed claimer, uint256 indexed tokenId, uint256 amount);

    // ------------------------------------------------------------------------
    // Constants
    // ------------------------------------------------------------------------

    uint256 public constant FREE_MINTS_PER_WALLET = 2;
    uint256 public constant MAX_MINTS_PER_WALLET = 10;
    uint256 public constant MAX_SUPPLY = 10_000;
    uint256 public constant PAID_MINT_PRICE = 0.005 ether;
    uint256 public constant MIN_BET = 0.001 ether;
    uint256 public constant MAX_BET = 0.05 ether;
    uint256 public constant MAX_LEVEL = 10;
    uint256 public constant WINNER_SHARE_BPS = 9_500; // winner takes 95% of the pot
    uint256 public constant BATTLE_FORGE_REWARD = 1_000 ether; // 1,000 FORGE to the winner

    uint256 public constant LEGENDARY_CAP = 100;
    uint256 public constant MYTHIC_CAP = 500;
    uint256 public constant RARE_CAP = 5_000;
    // Uncommon is uncapped.

    // ------------------------------------------------------------------------
    // State
    // ------------------------------------------------------------------------

    IERC721 public immutable registry;
    ForgeToken public immutable token;

    uint256 public seasonEnd;
    uint256 public seasonPool; // accounting variable (NOT raw balance)
    bool public snapshotDone;
    uint256 public snapshotPool;
    uint256 public snapshotTotalWeight;
    uint256 public totalTierWeight; // live sum of tier weights of all forged NFTs

    mapping(address => uint256) public freeMinted;
    mapping(address => uint256) public mintCountOf;
    mapping(uint256 => Hero) private _heroes;
    mapping(Tier => uint256) public forgeCount;
    mapping(uint256 => bool) public inBattle;
    mapping(uint256 => bool) public seasonClaimed;

    mapping(uint256 => Battle) private _battles;
    uint256 public nextBattleId = 1;

    uint256 public baseMinted; // free + paid mints (merges/forges do not count)
    uint256 private _nextTokenId = 1;
    uint256 public forgeNonce;

    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------

    /// @param registry_ Agent ID registry (mainnet 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F,
    ///        testnet the MockAgentIdRegistry deployed alongside).
    /// @param seasonDuration_ Season length in seconds (mainnet 30 days).
    constructor(address registry_, uint256 seasonDuration_) ERC721("AgentForge Hero", "AFHERO") Ownable(msg.sender) {
        require(registry_ != address(0), "registry zero");
        registry = IERC721(registry_);
        token = new ForgeToken(); // full fixed supply lands in this contract
        seasonEnd = block.timestamp + seasonDuration_;
    }

    // ------------------------------------------------------------------------
    // Views
    // ------------------------------------------------------------------------

    /// @notice Hard cap for a tier. Virtual so tests can deploy a harness
    ///         with small caps to exercise the downgrade path; the production
    ///         contract always returns the constants above.
    function tierCap(Tier tier) public pure virtual returns (uint256) {
        if (tier == Tier.LEGENDARY) return LEGENDARY_CAP;
        if (tier == Tier.MYTHIC) return MYTHIC_CAP;
        if (tier == Tier.RARE) return RARE_CAP;
        return type(uint256).max; // UNCOMMON (and NONE) uncapped
    }

    function levelOf(uint256 tokenId) external view returns (uint8) {
        return _heroes[tokenId].level;
    }

    function tierOf(uint256 tokenId) external view returns (Tier) {
        return _heroes[tokenId].tier;
    }

    /// @notice Battle power: base 100 + 25*(level-1), times the tier
    ///         multiplier (NONE x1, Uncommon x1.2, Rare x1.5, Mythic x2,
    ///         Legendary x3). Integer division truncates halves (e.g. a Lv2
    ///         Rare is 187, not 187.5); the same value is used for battle
    ///         odds, so odds stay consistent with what is shown.
    function powerOf(uint256 tokenId) public view returns (uint256) {
        Hero memory hero = _heroes[tokenId];
        uint256 base = 100 + 25 * (uint256(hero.level) - 1);
        return (base * _tierMultiplierBps(hero.tier)) / 10_000;
    }

    /// @notice Season-pool weight of a tier (SPEC: Uncommon 1 / Rare 5 /
    ///         Mythic 20 / Legendary 100 — Legendary is worth 100x
    ///         Uncommon). Base (NONE) heroes weigh 0: they earn battle
    ///         rewards only and do not share the season pool.
    function weightOf(Tier tier) public pure returns (uint256) {
        if (tier == Tier.UNCOMMON) return 1;
        if (tier == Tier.RARE) return 5;
        if (tier == Tier.MYTHIC) return 20;
        if (tier == Tier.LEGENDARY) return 100;
        return 0;
    }

    function heroOf(uint256 tokenId) external view returns (uint8 level, Tier tier, uint256 power) {
        Hero memory hero = _heroes[tokenId];
        return (hero.level, hero.tier, powerOf(tokenId));
    }

    function battleInfo(uint256 battleId) external view returns (Battle memory) {
        if (battleId == 0 || battleId >= nextBattleId) revert BattleNotFound();
        return _battles[battleId];
    }

    // ------------------------------------------------------------------------
    // Minting
    // ------------------------------------------------------------------------

    /// @notice Mint 1 free Hero (Lv1, tier NONE). Requires an Agent ID and
    ///         a remaining free slot (2 per wallet). Gas only.
    function mintFree() external returns (uint256 tokenId) {
        _requireAgentId(msg.sender);
        if (freeMinted[msg.sender] >= FREE_MINTS_PER_WALLET) revert FreeMintExhausted();
        if (mintCountOf[msg.sender] >= MAX_MINTS_PER_WALLET) revert MintCapExceeded();
        if (baseMinted >= MAX_SUPPLY) revert MaxSupplyExceeded();
        freeMinted[msg.sender]++;
        mintCountOf[msg.sender]++;
        baseMinted++;
        tokenId = _mintHero(msg.sender, 1, Tier.NONE);
        emit Mint(msg.sender, tokenId, 1, Tier.NONE, false);
    }

    /// @notice Mint `count` extra Heroes at 0.005 BNB each. Requires an
    ///         Agent ID. Wallet total (free + paid) is capped at 10.
    ///         100% of the payment goes to the season pool. No dev cut.
    function mintPaid(uint256 count) external payable returns (uint256[] memory tokenIds) {
        _requireAgentId(msg.sender);
        if (count == 0 || mintCountOf[msg.sender] + count > MAX_MINTS_PER_WALLET) revert MintCapExceeded();
        if (baseMinted + count > MAX_SUPPLY) revert MaxSupplyExceeded();
        uint256 expected = count * PAID_MINT_PRICE;
        if (msg.value != expected) revert IncorrectPayment(expected, msg.value);
        seasonPool += msg.value;
        mintCountOf[msg.sender] += count;
        baseMinted += count;
        tokenIds = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            tokenIds[i] = _mintHero(msg.sender, 1, Tier.NONE);
            emit Mint(msg.sender, tokenIds[i], 1, Tier.NONE, true);
        }
    }

    // ------------------------------------------------------------------------
    // Merge & forge
    // ------------------------------------------------------------------------

    /// @notice Burn two tier-NONE heroes owned by the caller and mint one
    ///         tier-NONE hero at level max(levelA, levelB) + 1 (max 10).
    ///         Lv10 is reached with 10 base heroes, not 512.
    function merge(uint256 tokenA, uint256 tokenB) external returns (uint256 newTokenId) {
        if (tokenA == tokenB) revert SameToken();
        if (ownerOf(tokenA) != msg.sender || ownerOf(tokenB) != msg.sender) revert NotTokenOwner();
        if (inBattle[tokenA] || inBattle[tokenB]) revert TokenInBattle();
        Hero memory a = _heroes[tokenA];
        Hero memory b = _heroes[tokenB];
        if (a.tier != Tier.NONE || b.tier != Tier.NONE) revert TierCannotMerge();
        uint256 maxLevel = a.level > b.level ? a.level : b.level;
        if (maxLevel >= MAX_LEVEL) revert MaxLevelReached();
        uint8 newLevel = uint8(maxLevel + 1);
        _burn(tokenA);
        _burn(tokenB);
        delete _heroes[tokenA];
        delete _heroes[tokenB];
        newTokenId = _mintHero(msg.sender, newLevel, Tier.NONE);
        emit Merge(msg.sender, tokenA, tokenB, newTokenId, newLevel);
    }

    /// @notice Burn a Lv10 tier-NONE hero and mint a tiered Lv10 hero.
    ///         Tier roll: Legendary 1% / Mythic 5% / Rare 20% / Uncommon 74%.
    ///         If the rolled tier has hit its hard cap, the result downgrades
    ///         to the next available tier (Uncommon is uncapped, so a forge
    ///         always succeeds). Tiered heroes cannot merge; they can battle.
    function forge(uint256 tokenId) external returns (uint256 newTokenId) {
        if (ownerOf(tokenId) != msg.sender) revert NotTokenOwner();
        if (inBattle[tokenId]) revert TokenInBattle();
        Hero memory hero = _heroes[tokenId];
        if (hero.tier != Tier.NONE) revert TierCannotForge();
        if (hero.level != MAX_LEVEL) revert NotMaxLevel();

        Tier rolled = _rollTier(tokenId);
        Tier resolved = _resolveTier(rolled);

        _burn(tokenId);
        delete _heroes[tokenId];
        newTokenId = _mintHero(msg.sender, uint8(MAX_LEVEL), resolved);
        forgeCount[resolved]++;
        totalTierWeight += weightOf(resolved);
        emit Forge(msg.sender, tokenId, newTokenId, resolved);
    }

    // ------------------------------------------------------------------------
    // Battle
    // ------------------------------------------------------------------------

    /// @notice Open a battle with `tokenId` as the stake (NFT escrowed) plus
    ///         a BNB bet of 0.001–0.05 BNB. The NFT itself is never at risk:
    ///         win or lose, both NFTs return to their owners; only the bet
    ///         is at stake.
    function createBattle(uint256 tokenId) external payable returns (uint256 battleId) {
        if (msg.value < MIN_BET || msg.value > MAX_BET) revert InvalidBet();
        if (ownerOf(tokenId) != msg.sender) revert NotTokenOwner();
        if (inBattle[tokenId]) revert TokenInBattle();
        battleId = nextBattleId++;
        _battles[battleId] = Battle({
            creator: msg.sender,
            challenger: address(0),
            creatorTokenId: tokenId,
            challengerTokenId: 0,
            bet: msg.value,
            status: BattleStatus.OPEN,
            winner: address(0)
        });
        inBattle[tokenId] = true;
        _transfer(msg.sender, address(this), tokenId); // escrow
        emit BattleCreated(battleId, msg.sender, tokenId, msg.value);
    }

    /// @notice Accept an open battle with your own hero and the same bet.
    ///         Resolves immediately: win chance = powerA / (powerA + powerB).
    ///         Winner takes 95% of the pot, 5% goes to the season pool, and
    ///         the winner also receives 1,000 FORGE. Both NFTs are returned.
    function acceptBattle(uint256 battleId, uint256 tokenId) external payable nonReentrant {
        if (battleId == 0 || battleId >= nextBattleId) revert BattleNotFound();
        Battle storage battle = _battles[battleId];
        if (battle.status != BattleStatus.OPEN) revert BattleNotOpen();
        if (msg.sender == battle.creator) revert SelfBattle();
        if (msg.value != battle.bet) revert IncorrectPayment(battle.bet, msg.value);
        if (ownerOf(tokenId) != msg.sender) revert NotTokenOwner();
        if (inBattle[tokenId]) revert TokenInBattle();

        battle.challenger = msg.sender;
        battle.challengerTokenId = tokenId;
        inBattle[tokenId] = true;
        _transfer(msg.sender, address(this), tokenId); // escrow

        uint256 powerA = powerOf(battle.creatorTokenId);
        uint256 powerB = powerOf(tokenId);
        uint256 rand = uint256(
            keccak256(abi.encodePacked(block.prevrandao, block.number, battleId, battle.creator, msg.sender))
        );
        address winner = (rand % (powerA + powerB) < powerA) ? battle.creator : msg.sender;
        address loser = winner == battle.creator ? msg.sender : battle.creator;

        uint256 pot = battle.bet * 2;
        uint256 winnerShare = (pot * WINNER_SHARE_BPS) / 10_000;
        uint256 poolShare = pot - winnerShare;

        battle.status = BattleStatus.RESOLVED;
        battle.winner = winner;
        inBattle[battle.creatorTokenId] = false;
        inBattle[tokenId] = false;
        seasonPool += poolShare;

        // Return both NFTs to their owners.
        _transfer(address(this), battle.creator, battle.creatorTokenId);
        _transfer(address(this), msg.sender, tokenId);

        emit BattleResolved(battleId, winner, loser, pot, winnerShare, poolShare);

        // Pay the winner (95% of the pot) and the 1,000 FORGE bonus.
        (bool ok,) = payable(winner).call{value: winnerShare}("");
        if (!ok) revert TransferFailed();
        if (!token.transfer(winner, BATTLE_FORGE_REWARD)) revert TransferFailed();

    }

    /// @notice Cancel an open battle (creator only, while OPEN). Refunds the
    ///         bet and returns the escrowed NFT.
    function cancelBattle(uint256 battleId) external nonReentrant {
        if (battleId == 0 || battleId >= nextBattleId) revert BattleNotFound();
        Battle storage battle = _battles[battleId];
        if (battle.status != BattleStatus.OPEN) revert BattleNotOpen();
        if (battle.creator != msg.sender) revert NotBattleCreator();
        battle.status = BattleStatus.CANCELLED;
        inBattle[battle.creatorTokenId] = false;
        _transfer(address(this), msg.sender, battle.creatorTokenId);
        emit BattleCancelled(battleId, msg.sender);
        (bool ok,) = payable(msg.sender).call{value: battle.bet}("");
        if (!ok) revert TransferFailed();

    }

    // ------------------------------------------------------------------------
    // Season
    // ------------------------------------------------------------------------

    /// @notice Freeze the season pool and total tier weight. Callable once,
    ///         by anyone, after `seasonEnd`. Later battles still add to the
    ///         live `seasonPool`, but claims use the frozen snapshot.
    function snapshotSeason() external {
        if (block.timestamp < seasonEnd) revert SeasonNotEnded();
        if (snapshotDone) revert SeasonAlreadySnapshotted();
        snapshotDone = true;
        snapshotPool = seasonPool;
        snapshotTotalWeight = totalTierWeight;
        emit SeasonSnapshot(snapshotPool, snapshotTotalWeight);
    }

    /// @notice Claim this tiered hero's share of the frozen season pool:
    ///         weight(token) / totalWeight * snapshotPool. One claim per
    ///         token. Base (NONE) heroes cannot claim.
    function claimSeasonReward(uint256 tokenId) external nonReentrant {
        if (!snapshotDone) revert SeasonNotSnapshotted();
        if (ownerOf(tokenId) != msg.sender) revert NotTokenOwner();
        Tier tier = _heroes[tokenId].tier;
        if (tier == Tier.NONE) revert NotTierNft();
        if (seasonClaimed[tokenId]) revert AlreadyClaimed();
        if (snapshotTotalWeight == 0) revert NoTierWeight();
        uint256 amount = (snapshotPool * weightOf(tier)) / snapshotTotalWeight;
        seasonClaimed[tokenId] = true;
        seasonPool -= amount;
        emit SeasonRewardClaimed(msg.sender, tokenId, amount);
        if (amount > 0) {
            (bool ok,) = payable(msg.sender).call{value: amount}("");
            if (!ok) revert TransferFailed();
        }

    }

    // ------------------------------------------------------------------------
    // Internal helpers
    // ------------------------------------------------------------------------

    function _requireAgentId(address account) internal view {
        if (registry.balanceOf(account) == 0) revert NoAgentId();
    }

    function _mintHero(address to, uint8 level, Tier tier) internal returns (uint256 tokenId) {
        tokenId = _nextTokenId++;
        _heroes[tokenId] = Hero({level: level, tier: tier});
        _safeMint(to, tokenId);
    }

    function _tierMultiplierBps(Tier tier) internal pure returns (uint256) {
        if (tier == Tier.UNCOMMON) return 12_000;
        if (tier == Tier.RARE) return 15_000;
        if (tier == Tier.MYTHIC) return 20_000;
        if (tier == Tier.LEGENDARY) return 30_000;
        return 10_000; // NONE
    }

    /// @dev prevrandao-based roll. 0 = Legendary, 1–5 = Mythic,
    ///      6–25 = Rare, 26–99 = Uncommon (percent buckets of rand % 100).
    function _rollTier(uint256 tokenId) internal returns (Tier) {
        uint256 rand = uint256(
            keccak256(abi.encodePacked(block.prevrandao, block.number, msg.sender, tokenId, forgeNonce))
        );
        forgeNonce++;
        uint256 r = rand % 100;
        if (r < 1) return Tier.LEGENDARY;
        if (r < 6) return Tier.MYTHIC;
        if (r < 26) return Tier.RARE;
        return Tier.UNCOMMON;
    }

    /// @dev Downgrade a rolled tier past any exhausted hard cap, one step at
    ///      a time. Uncommon is uncapped, so this always terminates.
    function _resolveTier(Tier rolled) internal view returns (Tier) {
        Tier tier = rolled;
        while (tier != Tier.UNCOMMON && forgeCount[tier] >= tierCap(tier)) {
            tier = Tier(uint8(tier) - 1);
        }
        return tier;
    }
}
