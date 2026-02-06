# Known issues and next steps

- add events for all state changing functions
- stale price check timeout should be changed depending on what chain protocol is deployed to
- need to check sequencer status when checking price staleness on Arbitrum
- add additional price oracles to act as fallbacks in case one is down 
- need to verify price feed decimals for collateral/usd price feeds instead of always assuming 1e8
- possibly add minimum balance check so small accounts are still worth liquidating or else small collateral balances could become unliquidatable
- need to refactor internal functions and break them up to give more control over when external calls happen so functions like `liquidate()` still follow CEI
- need to add some mechanism to allow liquidations even when enough DSC does not exist to liquidate or else users would have to deposit to liquidate then they would not have enough DSC to withdraw
  - maybe some sort of flash mint or flash loan system that charges a portion of the liquidation fee so it is easier to liquidate users when there is not much outstanding DSC
    - maybe even a DSC staking vault that allows flash loans for the purposes of liquidation that earns yield based on a liquidation fees collected?
    - or even feeless but only allow the flash loan/mint to be as large as the collateral being redeemed during liquidation
  - another option would be to allow liquidation using another stablecoin besides DSC as well
- maybe change use of transferFrom and burn in `DSCEngine::_burnDSC` to strictly burnFrom? could streamline the process and limit the amount of external calls. Would also have to change DecentralizedStableCoin contracts burn and burnFrom functions to support that
- need to implement solution to front running attacks on liquidators
