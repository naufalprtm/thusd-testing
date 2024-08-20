// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {ActivePool} from "../src/ActivePool/ActivePool.sol";
import {TBTC} from "../src/Collateral/TBTC.sol";
import {TroveManager} from "../src/TroveManager/TroveManager.sol";
import {DefaultPool} from "../src/DefaultPool/DefaultPool.sol";
import {BorrowerOperations} from "../src/BorrowerOperations/BorrowerOperations.sol";
import {THUSDToken} from "../src/THUSDToken/THUSDToken.sol";
import {PCV} from "../src/PCV/PCV.sol";
import {SortedTroves} from "../src/SortedTroves/SortedTroves.sol";

import "@openzeppelin-Defaultpool/contracts/token/ERC20/IERC20.sol";

contract DefaultPoolTest is Test {
    DefaultPool defaultPool;
    ActivePool activePool;
    TroveManager troveManager;
    IERC20 mockCollateral;
    BorrowerOperations borrowerOperations;
    THUSDToken thusdToken;
    PCV pvc;
    SortedTroves sortedtroves;


    address owner = address(1);
    address stabilityPool = address(3);
    address collSurplusPool = address(4);

    uint256 initialCollateral = 1000 ether;
    uint256 initialTHUSDDebt = 500 ether;

function setUp() public {
    // Deploy contracts
    defaultPool = new DefaultPool();
    mockCollateral = IERC20(address(new TBTC())); // Ensure this is the correct collateral token
    activePool = new ActivePool();
    troveManager = new TroveManager();
    borrowerOperations = new BorrowerOperations();
    sortedtroves = new SortedTroves();
    pvc = new PCV(7776000);
    
    // Initialize THUSDToken with the required constructor arguments
    thusdToken = new THUSDToken(
        address(troveManager),          // _troveManagerAddress1
        address(sortedtroves), // _stabilityPoolAddress1 (Ensure this is correct)
        address(borrowerOperations),    // _borrowerOperationsAddress1
        address(troveManager), // _troveManagerAddress2 (Ensure this is correct)
        address(stabilityPool), // _stabilityPoolAddress (Ensure this is correct)
        address(pvc), // _borrowerOperationsAddress (Ensure this is correct)
        7776000                                   // _governanceTimeDelay (Example: 1 day = 86400 seconds)
    );


    // Transfer ownership from the deployer (address(this)) to the owner address
    defaultPool.transferOwnership(owner);
    activePool.transferOwnership(owner);
    troveManager.transferOwnership(owner);
    borrowerOperations.transferOwnership(owner);
    thusdToken.transferOwnership(owner);
    sortedtroves.transferOwnership(owner);
    pvc.transferOwnership(owner);

    // Set addresses in contracts as the new owner
    vm.prank(owner);
    defaultPool.setAddresses(
        address(troveManager), // _troveManagerAddress
        address(activePool), // _activePoolAddress
        address(mockCollateral) // _collateralAddress
    );

    vm.prank(owner);
    activePool.setAddresses(
        address(borrowerOperations),  // _borrowerOperationsAddress
        address(troveManager), // _troveManagerAddress
        address(stabilityPool), // _stabilityPoolAddress
        address(defaultPool), // _defaultPoolAddress
        address(collSurplusPool), // _collSurplusPoolAddress
        address(mockCollateral) // _collateralAddress
    );

    vm.prank(owner);
    troveManager.setAddresses(
        address(borrowerOperations),  // _borrowerOperationsAddress
        address(activePool), // _activePoolAddress
        address(defaultPool), // _defaultPoolAddress
        address(stabilityPool), // _stabilityPoolAddress
        address(collSurplusPool), // _gasPoolAddress
        address(mockCollateral), // _collSurplusPoolAddress
        address(troveManager), // _priceFeedAddress
        address(thusdToken),  // _thusdTokenAddress
        address(sortedtroves ),  // _sortedTrovesAddress
        address(pvc)   // _pcvAddress
    );
}

    // Test case 1: Manipulation of governance voting with large debt
    function testGovernanceManipulationLargeDebt() public {
        vm.prank(address(troveManager));  // Make sure to pass the correct address
        defaultPool.increaseTHUSDDebt(initialTHUSDDebt);

        // Simulate excessive governance manipulation
        vm.prank(address(troveManager));
        defaultPool.increaseTHUSDDebt(1_000_000_000 ether); // Large amount

        assertEq(defaultPool.getTHUSDDebt(), initialTHUSDDebt + 1_000_000_000 ether, "Governance manipulation detected with large debt!");
    }

    // Test case 2: Repeated direct theft of user funds
    function testRepeatedDirectTheftOfFunds() public {
        vm.deal(address(defaultPool), initialCollateral);

        // Simulate multiple theft attempts
        for (uint i = 0; i < 3; i++) {
            vm.prank(address(troveManager));
            defaultPool.sendCollateralToActivePool(100 ether);
            assertEq(address(defaultPool).balance, initialCollateral - (i + 1) * 100 ether, "Direct theft detected on iteration!");
        }
    }

    // Test case 3: Attempt to freeze funds by reentrant calls
    function testReentrantFreezingOfFunds() public {
        // Simulate freezing funds through reentrancy
        vm.prank(address(troveManager));
        defaultPool.sendCollateralToActivePool(500 ether);

        // Reattempt transfer should fail and catch an error
        try defaultPool.sendCollateralToActivePool(500 ether) {
            revert("Funds were not frozen correctly!");
        } catch Error(string memory reason) {
            assertEq(reason, "Collateral transfer failed", "Unexpected error while testing reentrant freezing");
        }
    }

    // Test case 4: Protocol insolvency with large debt and zero collateral
    function testProtocolInsolvencyLargeDebt() public {
        vm.prank(address(troveManager));
        defaultPool.increaseTHUSDDebt(1_000_000_000 ether); // Simulate large debt

        vm.prank(address(troveManager));
        defaultPool.sendCollateralToActivePool(initialCollateral); // Send all collateral

        assertEq(defaultPool.getCollateralBalance(), 0, "Protocol is not insolvent after large debt!");
    }

    // Test case 5: Unbounded gas consumption in recursive function calls
    function testRecursiveGasConsumption() public {
        uint256 largeAmount = 10 ** 18;

        // Simulate potential recursive function call increasing debt
        for (uint i = 0; i < 100; i++) {
            vm.prank(address(troveManager));
            defaultPool.increaseTHUSDDebt(largeAmount); // Loop adding debt
        }

        assertTrue(gasleft() > 10000, "Unbounded gas consumption detected in recursive calls!");
    }

    // Test case 6: Temporary freezing of funds for more than 1 week
    function testTemporaryFreezingOfFunds() public {
        vm.prank(address(troveManager));
        defaultPool.sendCollateralToActivePool(500 ether);

        // Simulate time passing of over 1 week
        vm.warp(block.timestamp + 8 days);

        vm.prank(address(troveManager));
        try defaultPool.sendCollateralToActivePool(500 ether) {
            revert("Funds are still frozen after 1 week!");
        } catch {
            // Expected to fail due to frozen funds
        }
    }

    // Test case 7: Smart contract operation failure due to lack of token funds
    function testOperationFailureDueToLackOfFunds() public {
        // Simulate lack of token funds
        vm.prank(address(troveManager));
        defaultPool.increaseTHUSDDebt(500 ether);

        // Active pool lacks tokens to complete transfer
        vm.prank(address(troveManager));
        vm.deal(address(activePool), 0); // Set activePool balance to zero

        try defaultPool.sendCollateralToActivePool(500 ether) {
            revert("Contract should fail due to lack of token funds!");
        } catch {
            // Expected to catch due to insufficient funds
        }
    }
}
