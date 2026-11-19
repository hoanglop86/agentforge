// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {AgentForge} from "../src/AgentForge.sol";
import {ForgeToken} from "../src/ForgeToken.sol";
import {MockAgentIdRegistry} from "../src/MockAgentIdRegistry.sol";

/// @notice Harness with tiny tier caps (LG 1 / Mythic 1 / Rare 1) so the
///         forge downgrade path can be exercised without 100+ forges.
contract AgentForgeSmallCaps is AgentForge {
    constructor(address registry, uint256 seasonDuration) AgentForge(registry, seasonDuration) {}

    function tierCap(Tier tier) public pure override returns (uint256) {
        if (tier == Tier.LEGENDARY) return 1;
        if (tier == Tier.MYTHIC) return 1;
        if (tier == Tier.RARE) return 1;
        return type(uint256).max;
    }
}

/// @notice Harness where only Uncommon can ever be forged (all higher tiers
///         capped at 0), so season-claim math can be tested with known
///         equal weights.
contract AgentForgeUncommonOnly is AgentForge {
    constructor(address registry, uint256 seasonDuration) AgentForge(registry, seasonDuration) {}

    function tierCap(Tier tier) public pure override returns (uint256) {
        if (tier == Tier.UNCOMMON) return type(uint256).max;
        return 0;
    }
}

contract AgentForgeTest is Test {
    MockAgentIdRegistry internal registry;
    AgentForge internal game;
    ForgeToken internal forgeToken;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");
    address internal dave = makeAddr("dave");
    address internal eve = makeAddr("eve");
    address internal mallory = makeAddr("mallory"); // no Agent ID

    uint256 internal constant SEASON = 7 days;

    function setUp() public {
        registry = new MockAgentIdRegistry();
        game = new AgentForge(address(registry), SEASON);
        forgeToken = game.token();
        address[5] memory users = [alice, bob, carol, dave, eve];
        for (uint256 i = 0; i < users.length; i++) {
            registry.mint(users[i]);
            vm.deal(users[i], 10 ether);
        }
        vm.deal(mallory, 10 ether);
    }

    // ------------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------------

    /// @dev Mint 2 free + 8 paid, then merge up to Lv10. Returns the Lv10 id.
    function _mintLv10(address user) internal returns (uint256 lv10) {
        vm.startPrank(user);
        uint256[] memory ids = new uint256[](10);
        ids[0] = game.mintFree();
        ids[1] = game.mintFree();
        uint256[] memory paid = game.mintPaid{value: 8 * 0.005 ether}(8);
        for (uint256 i = 0; i < 8; i++) ids[2 + i] = paid[i];
        lv10 = game.merge(ids[0], ids[1]); // Lv2
        for (uint256 i = 2; i < 10; i++) {
            lv10 = game.merge(lv10, ids[i]); // Lv3..Lv10
        }
        vm.stopPrank();
        assertEq(game.levelOf(lv10), 10);
    }

    /// @dev Brute-force a prevrandao value whose forge roll lands in [lo, hi).
    function _findPrevrandaoForForge(address user, uint256 tokenId, uint256 nonce, uint256 lo, uint256 hi)
        internal
        view
        returns (bytes32)
    {
        for (uint256 i = 0; i < 100_000; i++) {
            bytes32 cand = bytes32(i);
            uint256 r =
                uint256(keccak256(abi.encodePacked(cand, block.number, user, tokenId, nonce))) % 100;
            if (r >= lo && r < hi) return cand;
        }
        revert("no prevrandao found");
    }

    /// @dev Brute-force a prevrandao value that makes the creator win (or lose).
    function _findPrevrandaoForBattle(
        uint256 battleId,
        address creator,
        address challenger,
        uint256 powerA,
        uint256 powerB,
        bool creatorWins
    ) internal view returns (bytes32) {
        for (uint256 i = 0; i < 100_000; i++) {
            bytes32 cand = bytes32(i);
            uint256 rand =
                uint256(keccak256(abi.encodePacked(cand, block.number, battleId, creator, challenger)));
            bool creatorWon = (rand % (powerA + powerB) < powerA);
            if (creatorWon == creatorWins) return cand;
        }
        revert("no prevrandao found");
    }

    // ------------------------------------------------------------------------
    // (a) Free mint
    // ------------------------------------------------------------------------

    function test_FreeMint_RequiresAgentId() public {
        vm.prank(mallory);
        vm.expectRevert(AgentForge.NoAgentId.selector);
        game.mintFree();
    }

    function test_FreeMint_TwoOk_ThirdReverts() public {
        vm.startPrank(alice);
        uint256 t1 = game.mintFree();
        uint256 t2 = game.mintFree();
        assertEq(game.freeMinted(alice), 2);
        assertEq(game.mintCountOf(alice), 2);
        assertEq(game.balanceOf(alice), 2);
        assertEq(game.levelOf(t1), 1);
        assertEq(uint8(game.tierOf(t1)), uint8(AgentForge.Tier.NONE));
        assertEq(uint8(game.tierOf(t2)), uint8(AgentForge.Tier.NONE));
        vm.expectRevert(AgentForge.FreeMintExhausted.selector);
        game.mintFree();
        vm.stopPrank();
    }

    // ------------------------------------------------------------------------
    // (b) Paid mint
    // ------------------------------------------------------------------------

    function test_PaidMint_WrongPriceReverts() public {
        vm.startPrank(alice);
        game.mintFree();
        game.mintFree();
        vm.expectRevert(
            abi.encodeWithSelector(AgentForge.IncorrectPayment.selector, 0.005 ether, 0.004 ether)
        );
        game.mintPaid{value: 0.004 ether}(1);
        vm.stopPrank();
    }

    function test_PaidMint_CapAndPool() public {
        vm.startPrank(alice);
        game.mintFree();
        game.mintFree();
        uint256[] memory ids = game.mintPaid{value: 8 * 0.005 ether}(8);
        assertEq(ids.length, 8);
        assertEq(game.mintCountOf(alice), 10);
        assertEq(game.seasonPool(), 8 * 0.005 ether);
        vm.expectRevert(AgentForge.MintCapExceeded.selector);
        game.mintPaid{value: 0.005 ether}(1);
        vm.expectRevert(AgentForge.MintCapExceeded.selector);
        game.mintPaid(0);
        vm.stopPrank();
    }

    function test_PaidMint_RequiresAgentId() public {
        vm.prank(mallory);
        vm.expectRevert(AgentForge.NoAgentId.selector);
        game.mintPaid{value: 0.005 ether}(1);
    }

    // ------------------------------------------------------------------------
    // (c) Merge
    // ------------------------------------------------------------------------

    function test_Merge_LevelsUp_BurnsTwoMintsOne() public {
        vm.startPrank(alice);
        uint256 a = game.mintFree();
        uint256 b = game.mintFree();
        uint256 c = game.merge(a, b);
        assertEq(game.levelOf(c), 2);
        assertEq(game.balanceOf(alice), 1);
        assertEq(uint8(game.tierOf(c)), uint8(AgentForge.Tier.NONE));
        // burned tokens no longer exist
        vm.expectRevert();
        game.ownerOf(a);
        vm.expectRevert();
        game.ownerOf(b);
        vm.stopPrank();
    }

    function test_Merge_ChainToLv3() public {
        vm.startPrank(alice);
        uint256 a = game.mintFree();
        uint256 b = game.mintFree();
        uint256 lv2 = game.merge(a, b);
        uint256[] memory paid = game.mintPaid{value: 0.005 ether}(1);
        uint256 lv3 = game.merge(lv2, paid[0]);
        assertEq(game.levelOf(lv3), 3);
        vm.stopPrank();
    }

    function test_Merge_MaxLevelReverts() public {
        uint256 lv10 = _mintLv10(alice);
        vm.prank(bob);
        uint256 spare = game.mintFree();
        vm.prank(bob);
        game.transferFrom(bob, alice, spare);
        vm.prank(alice);
        vm.expectRevert(AgentForge.MaxLevelReached.selector);
        game.merge(lv10, spare);
    }

    function test_Merge_NotOwnerReverts() public {
        vm.prank(alice);
        uint256 a = game.mintFree();
        vm.prank(bob);
        uint256 b = game.mintFree();
        vm.prank(bob);
        vm.expectRevert(AgentForge.NotTokenOwner.selector);
        game.merge(a, b);
    }

    function test_Merge_SameTokenReverts() public {
        vm.prank(alice);
        uint256 a = game.mintFree();
        vm.prank(alice);
        vm.expectRevert(AgentForge.SameToken.selector);
        game.merge(a, a);
    }

    function test_Merge_TierCannotMerge() public {
        uint256 lv10 = _mintLv10(alice);
        vm.prank(alice);
        uint256 forged = game.forge(lv10);
        vm.prank(bob);
        uint256 spare = game.mintFree();
        vm.prank(bob);
        game.transferFrom(bob, alice, spare);
        vm.prank(alice);
        vm.expectRevert(AgentForge.TierCannotMerge.selector);
        game.merge(forged, spare);
    }

    // ------------------------------------------------------------------------
    // (d) Forge
    // ------------------------------------------------------------------------

    function test_Forge_RequiresLv10() public {
        vm.prank(alice);
        uint256 t = game.mintFree();
        vm.prank(alice);
        vm.expectRevert(AgentForge.NotMaxLevel.selector);
        game.forge(t);
    }

    function test_Forge_Success_TierAssigned_Level10() public {
        uint256 lv10 = _mintLv10(alice);
        vm.prank(alice);
        uint256 forged = game.forge(lv10);
        assertEq(game.levelOf(forged), 10);
        assertTrue(game.tierOf(forged) != AgentForge.Tier.NONE);
        assertEq(game.balanceOf(alice), 1);
        assertEq(game.totalTierWeight(), game.weightOf(game.tierOf(forged)));
        // old token burned
        vm.expectRevert();
        game.ownerOf(lv10);
        // tiered hero cannot be forged again
        vm.prank(alice);
        vm.expectRevert(AgentForge.TierCannotForge.selector);
        game.forge(forged);
    }

    function test_Forge_Downgrade_WhenTierCapExhausted() public {
        AgentForgeSmallCaps small = new AgentForgeSmallCaps(address(registry), SEASON);
        address[4] memory users = [alice, bob, carol, dave];
        AgentForge.Tier[4] memory expected = [
            AgentForge.Tier.LEGENDARY,
            AgentForge.Tier.MYTHIC,
            AgentForge.Tier.RARE,
            AgentForge.Tier.UNCOMMON
        ];
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            // build a Lv10 on the small-caps game (same helper logic, other game)
            vm.startPrank(user);
            uint256[] memory ids = new uint256[](10);
            ids[0] = small.mintFree();
            ids[1] = small.mintFree();
            uint256[] memory paid = small.mintPaid{value: 8 * 0.005 ether}(8);
            for (uint256 j = 0; j < 8; j++) ids[2 + j] = paid[j];
            uint256 lv10 = small.merge(ids[0], ids[1]);
            for (uint256 j = 2; j < 10; j++) lv10 = small.merge(lv10, ids[j]);
            // force a Legendary roll (r < 1); caps push it down the ladder
            bytes32 prev = _findPrevrandaoForForge(user, lv10, small.forgeNonce(), 0, 1);
            vm.prevrandao(prev);
            uint256 forged = small.forge(lv10);
            vm.stopPrank();
            assertEq(uint8(small.tierOf(forged)), uint8(expected[i]));
        }
        assertEq(small.forgeCount(AgentForge.Tier.LEGENDARY), 1);
        assertEq(small.forgeCount(AgentForge.Tier.MYTHIC), 1);
        assertEq(small.forgeCount(AgentForge.Tier.RARE), 1);
        assertEq(small.forgeCount(AgentForge.Tier.UNCOMMON), 1);
    }

    function test_Forge_RollDistribution_UncommonBucket() public {
        // Force a roll in the Uncommon bucket (r in 26..99) on the real game.
        uint256 lv10 = _mintLv10(alice);
        bytes32 prev = _findPrevrandaoForForge(alice, lv10, game.forgeNonce(), 26, 100);
        vm.prevrandao(prev);
        vm.prank(alice);
        uint256 forged = game.forge(lv10);
        assertEq(uint8(game.tierOf(forged)), uint8(AgentForge.Tier.UNCOMMON));
    }

    // ------------------------------------------------------------------------
    // (e) Battle
    // ------------------------------------------------------------------------

    function test_Battle_Create_EscrowsNft() public {
        vm.prank(alice);
        uint256 t = game.mintFree();
        vm.prank(alice);
        uint256 battleId = game.createBattle{value: 0.01 ether}(t);
        assertEq(game.ownerOf(t), address(game));
        assertTrue(game.inBattle(t));
        AgentForge.Battle memory b = game.battleInfo(battleId);
        assertEq(uint8(b.status), uint8(AgentForge.BattleStatus.OPEN));
        assertEq(b.bet, 0.01 ether);
    }

    function test_Battle_Create_BadBetReverts() public {
        vm.prank(alice);
        uint256 t = game.mintFree();
        vm.prank(alice);
        vm.expectRevert(AgentForge.InvalidBet.selector);
        game.createBattle{value: 0.0005 ether}(t);
        vm.prank(alice);
        vm.expectRevert(AgentForge.InvalidBet.selector);
        game.createBattle{value: 0.06 ether}(t);
    }

    function test_Battle_Accept_WrongBetReverts() public {
        vm.prank(alice);
        uint256 ta = game.mintFree();
        vm.prank(bob);
        uint256 tb = game.mintFree();
        vm.prank(alice);
        uint256 battleId = game.createBattle{value: 0.01 ether}(ta);
        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(AgentForge.IncorrectPayment.selector, 0.01 ether, 0.02 ether)
        );
        game.acceptBattle{value: 0.02 ether}(battleId, tb);
    }

    function test_Battle_SelfAcceptReverts() public {
        vm.prank(alice);
        uint256 ta = game.mintFree();
        vm.prank(alice);
        uint256 tb = game.mintFree();
        vm.prank(alice);
        uint256 battleId = game.createBattle{value: 0.01 ether}(ta);
        vm.prank(alice);
        vm.expectRevert(AgentForge.SelfBattle.selector);
        game.acceptBattle{value: 0.01 ether}(battleId, tb);
    }

    function test_Battle_Cancel_RefundsBetAndNft() public {
        vm.prank(alice);
        uint256 t = game.mintFree();
        uint256 before = alice.balance;
        vm.prank(alice);
        uint256 battleId = game.createBattle{value: 0.01 ether}(t);
        vm.prank(alice);
        game.cancelBattle(battleId);
        assertEq(alice.balance, before);
        assertEq(game.ownerOf(t), alice);
        assertFalse(game.inBattle(t));
        assertEq(uint8(game.battleInfo(battleId).status), uint8(AgentForge.BattleStatus.CANCELLED));
        // accept after cancel reverts
        vm.prank(bob);
        uint256 tb = game.mintFree();
        vm.prank(bob);
        vm.expectRevert(AgentForge.BattleNotOpen.selector);
        game.acceptBattle{value: 0.01 ether}(battleId, tb);
    }

    function test_Battle_Cancel_NotCreatorReverts() public {
        vm.prank(alice);
        uint256 t = game.mintFree();
        vm.prank(alice);
        uint256 battleId = game.createBattle{value: 0.01 ether}(t);
        vm.prank(bob);
        vm.expectRevert(AgentForge.NotBattleCreator.selector);
        game.cancelBattle(battleId);
    }

    function test_Battle_Resolve_CreatorWins() public {
        vm.prank(alice);
        uint256 ta = game.mintFree();
        vm.prank(bob);
        uint256 tb = game.mintFree();
        uint256 aliceBefore = alice.balance;
        uint256 bobBefore = bob.balance;
        vm.prank(alice);
        uint256 battleId = game.createBattle{value: 0.01 ether}(ta);
        uint256 powerA = game.powerOf(ta);
        uint256 powerB = game.powerOf(tb);
        bytes32 prev = _findPrevrandaoForBattle(battleId, alice, bob, powerA, powerB, true);
        vm.prevrandao(prev);
        vm.prank(bob);
        game.acceptBattle{value: 0.01 ether}(battleId, tb);

        // pot 0.02: winner 95% = 0.019, pool 5% = 0.001
        assertEq(alice.balance, aliceBefore - 0.01 ether + 0.019 ether);
        assertEq(bob.balance, bobBefore - 0.01 ether);
        assertEq(forgeToken.balanceOf(alice), 1_000 ether);
        assertEq(forgeToken.balanceOf(bob), 0);
        assertEq(game.seasonPool(), 0.001 ether);
        assertEq(game.ownerOf(ta), alice);
        assertEq(game.ownerOf(tb), bob);
        assertFalse(game.inBattle(ta));
        assertFalse(game.inBattle(tb));
        AgentForge.Battle memory b = game.battleInfo(battleId);
        assertEq(uint8(b.status), uint8(AgentForge.BattleStatus.RESOLVED));
        assertEq(b.winner, alice);
    }

    function test_Battle_Resolve_ChallengerWins() public {
        vm.prank(alice);
        uint256 ta = game.mintFree();
        vm.prank(bob);
        uint256 tb = game.mintFree();
        uint256 bobBefore = bob.balance;
        vm.prank(alice);
        uint256 battleId = game.createBattle{value: 0.01 ether}(ta);
        uint256 powerA = game.powerOf(ta);
        uint256 powerB = game.powerOf(tb);
        bytes32 prev = _findPrevrandaoForBattle(battleId, alice, bob, powerA, powerB, false);
        vm.prevrandao(prev);
        vm.prank(bob);
        game.acceptBattle{value: 0.01 ether}(battleId, tb);
        assertEq(bob.balance, bobBefore - 0.01 ether + 0.019 ether);
        assertEq(forgeToken.balanceOf(bob), 1_000 ether);
        assertEq(game.battleInfo(battleId).winner, bob);
        assertEq(game.ownerOf(ta), alice);
        assertEq(game.ownerOf(tb), bob);
    }

    function test_Battle_TokenInBattleCannotReenter() public {
        vm.prank(alice);
        uint256 ta = game.mintFree();
        vm.prank(alice);
        game.createBattle{value: 0.01 ether}(ta);
        // Escrowed token: the creator no longer owns it, so re-entering any
        // action on it reverts (NotTokenOwner fires before the TokenInBattle
        // guard, which stays as defense-in-depth).
        vm.prank(alice);
        vm.expectRevert(AgentForge.NotTokenOwner.selector);
        game.createBattle{value: 0.01 ether}(ta);
        vm.prank(alice);
        uint256 tb = game.mintFree();
        vm.prank(alice);
        vm.expectRevert(AgentForge.NotTokenOwner.selector);
        game.merge(ta, tb);
    }

    // ------------------------------------------------------------------------
    // (f) Season
    // ------------------------------------------------------------------------

    function test_Season_SnapshotBeforeEndReverts() public {
        vm.expectRevert(AgentForge.SeasonNotEnded.selector);
        game.snapshotSeason();
    }

    function test_Season_FullFlow_ClaimMath_DoubleClaimReverts() public {
        AgentForgeUncommonOnly seasonal = new AgentForgeUncommonOnly(address(registry), 1 days);
        // Two users forge Uncommon Lv10s; each build pays 8 x 0.005 = 0.04 BNB
        // into the pool, so snapshotPool = 0.08 BNB and total weight = 2
        // (Uncommon weight 1 each).
        uint256 forgedA = _mintLv10On(address(seasonal), alice);
        uint256 forgedB = _mintLv10On(address(seasonal), bob);
        assertEq(uint8(seasonal.tierOf(forgedA)), uint8(AgentForge.Tier.UNCOMMON));
        assertEq(uint8(seasonal.tierOf(forgedB)), uint8(AgentForge.Tier.UNCOMMON));
        assertEq(seasonal.seasonPool(), 0.08 ether);

        // Claim before snapshot reverts.
        vm.prank(alice);
        vm.expectRevert(AgentForge.SeasonNotSnapshotted.selector);
        seasonal.claimSeasonReward(forgedA);

        vm.warp(block.timestamp + 1 days + 1);
        seasonal.snapshotSeason();
        assertTrue(seasonal.snapshotDone());
        assertEq(seasonal.snapshotPool(), 0.08 ether);
        assertEq(seasonal.snapshotTotalWeight(), 2);

        vm.expectRevert(AgentForge.SeasonAlreadySnapshotted.selector);
        seasonal.snapshotSeason();

        uint256 aliceBefore = alice.balance;
        vm.prank(alice);
        seasonal.claimSeasonReward(forgedA);
        assertEq(alice.balance, aliceBefore + 0.04 ether); // 1/2 of 0.08

        vm.prank(alice);
        vm.expectRevert(AgentForge.AlreadyClaimed.selector);
        seasonal.claimSeasonReward(forgedA);

        uint256 bobBefore = bob.balance;
        vm.prank(bob);
        seasonal.claimSeasonReward(forgedB);
        assertEq(bob.balance, bobBefore + 0.04 ether);
        assertEq(seasonal.seasonPool(), 0);
    }

    function test_Season_BaseNftCannotClaim() public {
        AgentForgeUncommonOnly seasonal = new AgentForgeUncommonOnly(address(registry), 1 days);
        uint256 forgedA = _mintLv10On(address(seasonal), alice);
        vm.prank(bob);
        uint256 base = seasonal.mintFree();
        vm.warp(block.timestamp + 1 days + 1);
        seasonal.snapshotSeason();
        assertTrue(seasonal.snapshotTotalWeight() > 0);
        vm.prank(bob);
        vm.expectRevert(AgentForge.NotTierNft.selector);
        seasonal.claimSeasonReward(base);
        // the tiered hero can still claim
        vm.prank(alice);
        seasonal.claimSeasonReward(forgedA);
    }

    /// @dev Same as _mintLv10 but on a given game instance; forges with a
    ///      forced Uncommon roll (caps in the harness make any roll Uncommon
    ///      anyway, so no prevrandao forcing is needed here).
    function _mintLv10On(address gameAddr, address user) internal returns (uint256 forged) {
        AgentForge g = AgentForge(gameAddr);
        vm.startPrank(user);
        uint256[] memory ids = new uint256[](10);
        ids[0] = g.mintFree();
        ids[1] = g.mintFree();
        uint256[] memory paid = g.mintPaid{value: 8 * 0.005 ether}(8);
        for (uint256 i = 0; i < 8; i++) ids[2 + i] = paid[i];
        uint256 lv10 = g.merge(ids[0], ids[1]);
        for (uint256 i = 2; i < 10; i++) lv10 = g.merge(lv10, ids[i]);
        forged = g.forge(lv10);
        vm.stopPrank();
    }

    function test_WeightOf_MatchesSpec() public view {
        // SPEC: Uncommon 1 / Rare 5 / Mythic 20 / Legendary 100 (LG = 100x Uncommon).
        assertEq(game.weightOf(AgentForge.Tier.NONE), 0);
        assertEq(game.weightOf(AgentForge.Tier.UNCOMMON), 1);
        assertEq(game.weightOf(AgentForge.Tier.RARE), 5);
        assertEq(game.weightOf(AgentForge.Tier.MYTHIC), 20);
        assertEq(game.weightOf(AgentForge.Tier.LEGENDARY), 100);
    }

    // ------------------------------------------------------------------------
    // Token sanity
    // ------------------------------------------------------------------------

    function test_ForgeToken_FixedSupplyHeldByGame() public {
        assertEq(forgeToken.totalSupply(), 1_000_000_000 ether);
        assertEq(forgeToken.balanceOf(address(game)), 1_000_000_000 ether);
        assertEq(forgeToken.name(), "AgentForge");
        assertEq(forgeToken.symbol(), "FORGE");
        assertEq(forgeToken.decimals(), 18);
    }

    function test_Power_Math() public {
        vm.prank(alice);
        uint256 t = game.mintFree();
        assertEq(game.powerOf(t), 100); // Lv1 NONE
        uint256 lv10 = _mintLv10(bob);
        assertEq(game.powerOf(lv10), 325); // Lv10 NONE: 100 + 25*9
        vm.prank(bob);
        uint256 forged = game.forge(lv10);
        // tier multiplier applied: power in [390 (Unc), 487 (Rare), 650 (Mythic), 975 (Leg)]
        uint256 p = game.powerOf(forged);
        assertTrue(p == 390 || p == 487 || p == 650 || p == 975);
    }
}
