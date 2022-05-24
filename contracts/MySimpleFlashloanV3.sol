// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.10;
pragma experimental ABIEncoderV2;

import {
    IPoolAddressesProvider
} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import { IPool } from "@aave/core-v3/contracts/interfaces/IPool.sol";
import { IFlashLoanSimpleReceiver } from "@aave/core-v3/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";
import { IERC20 } from "@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol";
import { SafeMath } from "@aave/core-v3/contracts/dependencies/openzeppelin/contracts/SafeMath.sol";

interface IFaucet {
    function mint(
        address _token,
        uint256 _amount
    ) external;
}

abstract contract FlashLoanSimpleReceiverBase is IFlashLoanSimpleReceiver {
  using SafeMath for uint256;

  IPoolAddressesProvider public immutable override ADDRESSES_PROVIDER;
  IPool public immutable override POOL;
  IFaucet public immutable FAUCET;

  constructor(IPoolAddressesProvider provider, IFaucet faucet) {
    ADDRESSES_PROVIDER = provider;
    POOL = IPool(provider.getPool());
    FAUCET = faucet;
  }
}


/** 
    !!!
    Never keep funds permanently on your FlashLoanSimpleReceiverBase contract as they could be 
    exposed to a 'griefing' attack, where the stored funds are used by an attacker.
    !!!
 */
contract MySimpleFlashLoanV3 is FlashLoanSimpleReceiverBase {
    using SafeMath for uint256;

    constructor(IPoolAddressesProvider _addressProvider, IFaucet _faucet) FlashLoanSimpleReceiverBase(_addressProvider, _faucet) {}

    /**
        This function is called after your contract has received the flash loaned amount
     */
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    )
        external
        override
        returns (bool)
    {

        //
        // This contract now has the funds requested.
        // Business logic - note: assume subscriber has a debt position opened on Aave, deposited <= 1ETH, and collateralised. 

        // 1. MaxBorrow USDC from AaveV3 
        // 2. (Manually monitor health score for demo) Run script to cause health score to drop to liquidation threshold subscriber set
        // 3. Execute flashLoanSimple
        // 4. Repay portion of subscriber's loan to boost health score with aUSDC
        // 5. Transfer collected collateral to subscribers wallet (Collateral - transaction fees)  
        // 6. Repay to Aave (Collateral Balance - flashloaned amount + premium). Note: ensure enough funds in contract
        

        // Step 6. Approve the LendingPool contract allowance to *pull* the owed amount
        uint amountOwed = amount.add(premium);
        FAUCET.mint(asset,premium);
        IERC20(asset).approve(address(POOL), amountOwed);

        return true;
    }

    // This function is executed in Remix - specify address (eg. USDC smart contract address, amount)
    function executeFlashLoan(
        address asset,
        uint256 amount
    ) public {
        address receiverAddress = address(this);

        bytes memory params = "";
        uint16 referralCode = 0;

        POOL.flashLoanSimple(
            receiverAddress,
            asset,
            amount,
            params,
            referralCode
        );
    }
}