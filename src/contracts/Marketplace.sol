// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {EventBeacon} from "./events/EventBeacon.sol";
import {Errors, Events} from "./shared/Monitoring.sol";
import {IEvent} from "./events/IEvent.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

/// @notice @title Marketplace provides an administrative panel for the marketplace
contract Marketplace is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    EventBeacon public BEACON_;
    EnumerableSet.AddressSet private _deployedTicketProxies;

    /* ================================================ METHODS =============================================== */

    constructor(address initialOwner_) Ownable(initialOwner_) {}

    function createEvent(
        string calldata eventIdentifier_,
        string calldata name_,
        string calldata symbol_,
        uint256 saleStart_,
        uint256 saleEnd_,
        uint256 ticketPrice_
    ) external {
        if (
            bytes(eventIdentifier_).length == 0 ||
            bytes(name_).length == 0 ||
            bytes(symbol_).length == 0 ||
            saleStart_ < block.number ||
            saleEnd_ <= saleStart_ ||
            ticketPrice_ == 0
        ) revert Errors.InvalidIO();

        _deployProxy(eventIdentifier_, name_, symbol_, msg.sender, saleStart_, saleEnd_, ticketPrice_);
    }

    /* ================================================= OWNER ================================================ */

    /// @notice Setups the Events structure
    function setupEvents(address implementation_) external onlyOwner {
        BEACON_ = new EventBeacon(implementation_, address(this));
    }

    /// @notice Updates the base implementation
    function updateImplementation(address new_) external onlyOwner {
        address prev = BEACON_.implementation();
        BEACON_.upgradeTo(new_);
        emit Events.BaseImplementationChanged(prev, new_);
    }

    /* ================================================= VIEW ================================================= */

    // `getCurrentImpl`?

    function getAllProxies() public view returns (address[] memory res) {
        uint256 len = _deployedTicketProxies.length();
        res = new address[](len);
        for (uint256 i; i < len; i++) {
            res[i] = _deployedTicketProxies.at(i);
        }
    }

    /* ================================================ PRIVATE =============================================== */

    function _deployProxy(
        string calldata eventIdentifier_,
        string calldata name_,
        string calldata symbol_,
        address eventCreator_,
        uint256 saleStart_,
        uint256 saleEnd_,
        uint256 ticketPrice_
    ) internal {
        bytes memory data = abi.encodeWithSelector(
            IEvent.initialize.selector,
            eventIdentifier_,
            name_,
            symbol_,
            eventCreator_,
            saleStart_,
            saleEnd_,
            ticketPrice_
        );
        address newProxyAddr = address(new BeaconProxy(address(BEACON_), data));
        bool ok = _deployedTicketProxies.add(newProxyAddr);
        if (!ok) revert Errors.ProxyAlreadyPresent();
        emit Events.ProxyDeployed(msg.sender, newProxyAddr);
    }
}