#!/bin/bash
# AgentForge E2E instance 1 (7-day season) — run from ~/workspace/agent-id-hackathon
set -u
export PATH="$PATH:$HOME/.foundry/bin"
cd ~/workspace/agent-id-hackathon
RPC=https://bsc-testnet-dataseed.bnbchain.org
GAME=0x69Fd48117Ec4f920501B573096133fefEA2c6096
REG=0x4315F61dE24A1e7B0fA0199CF49Be742432D7dcd
TOKEN=0x79A82C7a2234e34E1108665Bbc9EBC6Ef1aCe710
KEY1=$(cat .deployer-key-testnet)
KEY2=$(cat .tester2-key-testnet)
A1=0x7455764740784BbFa3Fd165c16eFfA0E396Cd5CA
A2=0xcF390d3a84bEa917c917795F2d59Fcc53C6dDD60
GAS="--gas-price 1000000000 --priority-gas-price 1000000000"
LOG=docs/e2e-inst1.log
: > $LOG

step() { echo "=== $* ===" | tee -a $LOG; }
send() { cast send "$@" --rpc-url $RPC $GAS 2>&1 | tee -a $LOG | grep -E "transactionHash|status|blockNumber|gasUsed|error|Error" ; }
call() { cast call "$@" --rpc-url $RPC 2>&1 | tee -a $LOG; }

step "1. mintFree #2 (wallet 1)"
send $GAME "mintFree()" --private-key $KEY1
step "heroOf(2)"
call $GAME "heroOf(uint256)(uint8,uint8,uint256)" 2
step "freeMinted(A1) expect 2"
call $GAME "freeMinted(address)(uint256)" $A1
step "3rd mintFree simulated (expect revert FreeMintExhausted)"
cast call $GAME "mintFree()" --from $A1 --rpc-url $RPC 2>&1 | tee -a $LOG

step "2. mintPaid(8) value 0.04"
send $GAME "mintPaid(uint256)" 8 --value 0.04ether --private-key $KEY1
step "mintCountOf(A1) expect 10"
call $GAME "mintCountOf(address)(uint256)" $A1
step "seasonPool expect 0.04 ether"
call $GAME "seasonPool()(uint256)"

step "3. merge chain -> Lv10"
for pair in "1 2" "11 3" "12 4" "13 5" "14 6" "15 7" "16 8" "17 9" "18 10"; do
  set -- $pair
  echo "-- merge $1 + $2" | tee -a $LOG
  send $GAME "merge(uint256,uint256)" $1 $2 --private-key $KEY1
done
step "heroOf(19) expect level 10, tier 0, power 325"
call $GAME "heroOf(uint256)(uint8,uint8,uint256)" 19

step "4. forge(19) -> token 20"
send $GAME "forge(uint256)" 19 --private-key $KEY1
step "heroOf(20)"
call $GAME "heroOf(uint256)(uint8,uint8,uint256)" 20
TIER=$(cast call $GAME "tierOf(uint256)(uint8)" 20 --rpc-url $RPC 2>/dev/null | tr -d ' \n')
echo "tierOf(20) = $TIER" | tee -a $LOG
step "weightOf(tier $TIER)"
call $GAME "weightOf(uint8)(uint256)" $TIER
step "forgeCount(tier $TIER)"
call $GAME "forgeCount(uint8)(uint256)" $TIER

step "5. tester2: mintSelf + 2x mintFree"
send $REG "mintSelf()" --private-key $KEY2
send $GAME "mintFree()" --private-key $KEY2
send $GAME "mintFree()" --private-key $KEY2
step "heroOf(21)"
call $GAME "heroOf(uint256)(uint8,uint8,uint256)" 21

step "6. battle: create with token 20, bet 0.001 (wallet 1)"
send $GAME "createBattle(uint256)" 20 --value 0.001ether --private-key $KEY1
step "accept with token 21, bet 0.001 (wallet 2)"
send $GAME "acceptBattle(uint256,uint256)" 1 21 --value 0.001ether --private-key $KEY2

step "battle checks"
echo "-- battleInfo(1)" | tee -a $LOG
call $GAME "battleInfo(uint256)" 1
echo "-- ownerOf(20) expect A1" | tee -a $LOG
call $GAME "ownerOf(uint256)(address)" 20
echo "-- ownerOf(21) expect A2" | tee -a $LOG
call $GAME "ownerOf(uint256)(address)" 21
echo "-- seasonPool expect 0.0401 ether" | tee -a $LOG
call $GAME "seasonPool()(uint256)"
echo "-- FORGE balances" | tee -a $LOG
echo "A1:" | tee -a $LOG; call $TOKEN "balanceOf(address)(uint256)" $A1
echo "A2:" | tee -a $LOG; call $TOKEN "balanceOf(address)(uint256)" $A2
step "balances"
echo "A1 tBNB:" | tee -a $LOG; cast balance $A1 --rpc-url $RPC | tee -a $LOG
echo "A2 tBNB:" | tee -a $LOG; cast balance $A2 --rpc-url $RPC | tee -a $LOG
step "INSTANCE 1 DONE"
