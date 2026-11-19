#!/bin/bash
# AgentForge E2E instance 2 (600s season) — run from ~/workspace/agent-id-hackathon
set -u
export PATH="$PATH:$HOME/.foundry/bin"
cd ~/workspace/agent-id-hackathon
RPC=https://bsc-testnet-dataseed.bnbchain.org
GAME=0xfd51891a7df468f0e6c3dd49a09257e49b3e4832
REG=0x3adab0edc1a36b0cf476aaf8c6ee0f401dc60892
KEY1=$(cat .deployer-key-testnet)
KEY2=$(cat .tester2-key-testnet)
A1=0x7455764740784BbFa3Fd165c16eFfA0E396Cd5CA
A2=0xcF390d3a84bEa917c917795F2d59Fcc53C6dDD60
GAS="--gas-price 1000000000 --priority-gas-price 1000000000"
LOG=docs/e2e-inst2.log
: > $LOG

step() { echo "=== $* ===" | tee -a $LOG; }
send() { cast send "$@" --rpc-url $RPC $GAS 2>&1 | tee -a $LOG | grep -E "transactionHash|status|blockNumber|gasUsed|error|Error"; }
call() { cast call "$@" --rpc-url $RPC 2>&1 | tee -a $LOG; }

step "0. deploy receipts"
cast receipt 0x5156149ab16b84bf665ca262e8362c235dfc83f80eb266717ed55bce33252475 --rpc-url $RPC 2>&1 | tee -a $LOG | grep -E "transactionHash|status|blockNumber|gasUsed"
cast receipt 0x78628798f4088ae5966dea62f8620006c5372af4b827f067f8d423a424212e31 --rpc-url $RPC 2>&1 | tee -a $LOG | grep -E "transactionHash|status|blockNumber|gasUsed"
step "seasonEnd"
SEASON_END=$(cast call $GAME "seasonEnd()(uint256)" --rpc-url $RPC 2>/dev/null | tr -d ' \n')
echo "seasonEnd = $SEASON_END" | tee -a $LOG
step "token() / registry()"
call $GAME "token()(address)"
call $GAME "registry()(address)"

step "1. mintSelf on REG2 (both wallets)"
send $REG "mintSelf()" --private-key $KEY1
send $REG "mintSelf()" --private-key $KEY2
call $REG "balanceOf(address)(uint256)" $A1
call $REG "balanceOf(address)(uint256)" $A2

step "2. wallet1 mintFree x2"
send $GAME "mintFree()" --private-key $KEY1
send $GAME "mintFree()" --private-key $KEY1

step "3. wallet1 mintPaid(8) value 0.04"
send $GAME "mintPaid(uint256)" 8 --value 0.04ether --private-key $KEY1
step "mintCountOf(A1) expect 10"
call $GAME "mintCountOf(address)(uint256)" $A1
step "seasonPool expect 0.04 ether"
call $GAME "seasonPool()(uint256)"

step "4. merge chain -> Lv10 (token 19)"
for pair in "1 2" "11 3" "12 4" "13 5" "14 6" "15 7" "16 8" "17 9" "18 10"; do
  set -- $pair
  echo "-- merge $1 + $2" | tee -a $LOG
  send $GAME "merge(uint256,uint256)" $1 $2 --private-key $KEY1
done
step "heroOf(19) expect level 10, tier 0, power 325"
call $GAME "heroOf(uint256)(uint8,uint8,uint256)" 19

step "5. forge(19) -> token 20"
send $GAME "forge(uint256)" 19 --private-key $KEY1
step "heroOf(20)"
call $GAME "heroOf(uint256)(uint8,uint8,uint256)" 20
TIER=$(cast call $GAME "tierOf(uint256)(uint8)" 20 --rpc-url $RPC 2>/dev/null | tr -d ' \n')
echo "tierOf(20) = $TIER" | tee -a $LOG
step "weightOf(tier $TIER)"
call $GAME "weightOf(uint8)(uint256)" $TIER
step "totalTierWeight"
call $GAME "totalTierWeight()(uint256)"

step "6. tester2 mintFree x2 on GAME2"
send $GAME "mintFree()" --private-key $KEY2
send $GAME "mintFree()" --private-key $KEY2

step "7. battle on GAME2: create token 20 bet 0.001 (wallet 1)"
send $GAME "createBattle(uint256)" 20 --value 0.001ether --private-key $KEY1
step "accept with token 21 bet 0.001 (wallet 2)"
send $GAME "acceptBattle(uint256,uint256)" 1 21 --value 0.001ether --private-key $KEY2
step "battleInfo(1)"
call $GAME "battleInfo(uint256)" 1
step "seasonPool expect 0.0401 ether"
call $GAME "seasonPool()(uint256)"

step "8. wait for season end"
NOW=$(date +%s)
WAIT=$((SEASON_END - NOW + 15))
echo "now=$NOW seasonEnd=$SEASON_END waiting ${WAIT}s" | tee -a $LOG
if [ "$WAIT" -gt 0 ]; then sleep $WAIT; fi
step "seasonEnd check"
call $GAME "seasonEnd()(uint256)"

step "9. snapshotSeason"
send $GAME "snapshotSeason()" --private-key $KEY1
step "snapshotPool expect 0.0401 ether"
call $GAME "snapshotPool()(uint256)"
step "snapshotTotalWeight expect = weight of the single tier NFT"
call $GAME "snapshotTotalWeight()(uint256)"

step "10. claimSeasonReward(20) — pays in tBNB"
echo "A1 tBNB before claim:" | tee -a $LOG
cast balance $A1 --rpc-url $RPC | tee -a $LOG
send $GAME "claimSeasonReward(uint256)" 20 --private-key $KEY1
echo "A1 tBNB after claim:" | tee -a $LOG
cast balance $A1 --rpc-url $RPC | tee -a $LOG
step "seasonPool after claim expect 0"
call $GAME "seasonPool()(uint256)"
step "seasonClaimed(20) expect true"
call $GAME "seasonClaimed(uint256)(bool)" 20
step "2nd claim simulated (expect revert AlreadyClaimed)"
cast call $GAME "claimSeasonReward(uint256)" 20 --from $A1 --rpc-url $RPC 2>&1 | tee -a $LOG
step "snapshotSeason again simulated (expect revert SeasonAlreadySnapshotted)"
cast call $GAME "snapshotSeason()" --from $A1 --rpc-url $RPC 2>&1 | tee -a $LOG

step "balances"
echo "A1 tBNB:" | tee -a $LOG; cast balance $A1 --rpc-url $RPC | tee -a $LOG
echo "A2 tBNB:" | tee -a $LOG; cast balance $A2 --rpc-url $RPC | tee -a $LOG
step "INSTANCE 2 DONE"
