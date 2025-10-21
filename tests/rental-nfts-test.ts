import { describe, it, expect, beforeEach } from "vitest";
import { Simnet } from "@hirosystems/clarinet-sdk";

const accounts = simnet.getAccounts();
const deployerAddress = accounts.get("deployer")!;
const landlordAddress = accounts.get("wallet_1")!;
const tenantAddress = accounts.get("wallet_2")!;
const contractorAddress = accounts.get("wallet_3")!;

const contractName = "rental-nfts-for-real-estate";

describe("Rental NFTs with Maintenance Tracking", () => {
  let simnet: Simnet;

  beforeEach(() => {
    simnet = new Simnet();
  });

  describe("Core Rental Functions", () => {
    it("should allow listing a property", () => {
      const listResult = simnet.callPublicFn(
        contractName,
        "list-property",
        [
          "u100", // rent per block
          "u5000", // deposit
          "u1440", // max duration  
          "\"123 Main St\"",
          "\"Beautiful property\""
        ],
        landlordAddress
      );

      expect(listResult.result).toBe("(ok u1)");
    });

    it("should allow renting a property", () => {
      // First list a property
      simnet.callPublicFn(
        contractName,
        "list-property", 
        ["u100", "u5000", "u1440", "\"123 Main St\"", "\"Beautiful property\""],
        landlordAddress
      );

      // Then rent it
      const rentResult = simnet.callPublicFn(
        contractName,
        "rent-property",
        ["u1", "u720"], // property ID 1, rent for 720 blocks
        tenantAddress
      );

      expect(rentResult.result).toBe("(ok true)");
    });

    it("should allow check-in and check-out", () => {
      // Setup: list and rent property
      simnet.callPublicFn(contractName, "list-property", 
        ["u100", "u5000", "u1440", "\"123 Main St\"", "\"Beautiful property\""], 
        landlordAddress);
      
      simnet.callPublicFn(contractName, "rent-property", 
        ["u1", "u720"], tenantAddress);

      // Check in
      const checkinResult = simnet.callPublicFn(
        contractName,
        "check-in",
        ["u1"],
        tenantAddress
      );
      expect(checkinResult.result).toBe("(ok true)");

      // Check out
      const checkoutResult = simnet.callPublicFn(
        contractName,
        "check-out", 
        ["u1"],
        tenantAddress
      );
      expect(checkoutResult.result).toBe("(ok true)");
    });
  });

  describe("NEW FEATURE: Maintenance Tracking System", () => {
    beforeEach(() => {
      // Setup: list a property for maintenance tests
      simnet.callPublicFn(
        contractName,
        "list-property",
        ["u100", "u5000", "u1440", "\"123 Main St\"", "\"Test property\""],
        landlordAddress
      );

      // Authorize a contractor
      simnet.callPublicFn(
        contractName,
        "authorize-contractor",
        [contractorAddress],
        deployerAddress
      );
    });

    it("should allow creating maintenance requests", () => {
      const result = simnet.callPublicFn(
        contractName,
        "create-maintenance-request",
        [
          "u1", // property ID
          "u1", // request type (plumbing)
          "\"Leaky faucet in kitchen\"", // description
          "u2", // priority (urgent)
          "u250" // estimated cost
        ],
        landlordAddress
      );

      expect(result.result).toBe("(ok u1)");
    });

    it("should allow assigning contractors to maintenance requests", () => {
      // Create maintenance request first
      simnet.callPublicFn(
        contractName,
        "create-maintenance-request",
        ["u1", "u1", "\"Leaky faucet\"", "u2", "u250"],
        landlordAddress
      );

      // Assign contractor
      const result = simnet.callPublicFn(
        contractName,
        "assign-contractor",
        ["u1", contractorAddress], // maintenance ID 1
        landlordAddress
      );

      expect(result.result).toBe("(ok true)");
    });

    it("should allow contractors to start and complete work", () => {
      // Setup: create request and assign contractor
      simnet.callPublicFn(contractName, "create-maintenance-request",
        ["u1", "u1", "\"Leaky faucet\"", "u2", "u250"], landlordAddress);
      
      simnet.callPublicFn(contractName, "assign-contractor",
        ["u1", contractorAddress], landlordAddress);

      // Contractor starts work
      const startResult = simnet.callPublicFn(
        contractName,
        "start-maintenance-work", 
        ["u1"],
        contractorAddress
      );
      expect(startResult.result).toBe("(ok true)");

      // Contractor completes work
      const completeResult = simnet.callPublicFn(
        contractName,
        "complete-maintenance-work",
        ["u1", "u200", "\"Fixed successfully\""], // actual cost, notes
        contractorAddress
      );
      expect(completeResult.result).toBe("(ok true)");
    });

    it("should allow rating contractors after work completion", () => {
      // Setup: complete maintenance workflow
      simnet.callPublicFn(contractName, "create-maintenance-request",
        ["u1", "u1", "\"Leaky faucet\"", "u2", "u250"], landlordAddress);
      simnet.callPublicFn(contractName, "assign-contractor", 
        ["u1", contractorAddress], landlordAddress);
      simnet.callPublicFn(contractName, "start-maintenance-work",
        ["u1"], contractorAddress);
      simnet.callPublicFn(contractName, "complete-maintenance-work",
        ["u1", "u200", "\"Fixed successfully\""], contractorAddress);

      // Rate contractor
      const rateResult = simnet.callPublicFn(
        contractName,
        "rate-contractor",
        ["u1", "u5"], // maintenance ID, rating (5 stars)
        landlordAddress
      );

      expect(rateResult.result).toBe("(ok true)");
    });

    it("should track property maintenance costs", () => {
      // Setup and complete maintenance
      simnet.callPublicFn(contractName, "create-maintenance-request",
        ["u1", "u1", "\"Leaky faucet\"", "u2", "u250"], landlordAddress);
      simnet.callPublicFn(contractName, "assign-contractor",
        ["u1", contractorAddress], landlordAddress);
      simnet.callPublicFn(contractName, "start-maintenance-work",
        ["u1"], contractorAddress);
      simnet.callPublicFn(contractName, "complete-maintenance-work",
        ["u1", "u200", "\"Fixed successfully\""], contractorAddress);

      // Check maintenance costs
      const costResult = simnet.callReadOnlyFn(
        contractName,
        "get-property-maintenance-costs",
        ["u1"],
        deployerAddress
      );

      expect(costResult.result).toBe("u200");
    });

    it("should allow cancelling maintenance requests", () => {
      // Create maintenance request
      simnet.callPublicFn(contractName, "create-maintenance-request",
        ["u1", "u1", "\"Leaky faucet\"", "u2", "u250"], landlordAddress);

      // Cancel request
      const cancelResult = simnet.callPublicFn(
        contractName,
        "cancel-maintenance-request",
        ["u1"],
        landlordAddress
      );

      expect(cancelResult.result).toBe("(ok true)");
    });
  });

  describe("Read-Only Functions", () => {
    it("should return property listings", () => {
      simnet.callPublicFn(contractName, "list-property",
        ["u100", "u5000", "u1440", "\"123 Main St\"", "\"Beautiful property\""],
        landlordAddress);

      const result = simnet.callReadOnlyFn(
        contractName,
        "get-property-listing",
        ["u1"],
        deployerAddress
      );

      expect(result.result).toContain("landlord:");
      expect(result.result).toContain("rent-per-block: u100");
    });

    it("should return maintenance request details", () => {
      // Setup
      simnet.callPublicFn(contractName, "list-property",
        ["u100", "u5000", "u1440", "\"123 Main St\"", "\"Test property\""],
        landlordAddress);
      
      simnet.callPublicFn(contractName, "create-maintenance-request",
        ["u1", "u1", "\"Leaky faucet\"", "u2", "u250"], landlordAddress);

      const result = simnet.callReadOnlyFn(
        contractName,
        "get-maintenance-request",
        ["u1"],
        deployerAddress
      );

      expect(result.result).toContain("property-id: u1");
      expect(result.result).toContain("request-type: u1");
      expect(result.result).toContain("status: u1");
    });

    it("should return contractor ratings", () => {
      // Setup complete maintenance workflow to generate rating
      simnet.callPublicFn(contractName, "list-property",
        ["u100", "u5000", "u1440", "\"123 Main St\"", "\"Test property\""],
        landlordAddress);
      simnet.callPublicFn(contractName, "authorize-contractor",
        [contractorAddress], deployerAddress);
      simnet.callPublicFn(contractName, "create-maintenance-request",
        ["u1", "u1", "\"Leaky faucet\"", "u2", "u250"], landlordAddress);
      simnet.callPublicFn(contractName, "assign-contractor",
        ["u1", contractorAddress], landlordAddress);
      simnet.callPublicFn(contractName, "start-maintenance-work",
        ["u1"], contractorAddress);
      simnet.callPublicFn(contractName, "complete-maintenance-work",
        ["u1", "u200", "\"Fixed successfully\""], contractorAddress);
      simnet.callPublicFn(contractName, "rate-contractor",
        ["u1", "u4"], landlordAddress);

      const result = simnet.callReadOnlyFn(
        contractName,
        "get-contractor-rating",
        [contractorAddress],
        deployerAddress
      );

      expect(result.result).toContain("average-rating: u4");
      expect(result.result).toContain("total-jobs: u1");
    });
  });

  describe("Error Cases", () => {
    it("should reject unauthorized maintenance requests", () => {
      // List property with landlord
      simnet.callPublicFn(contractName, "list-property",
        ["u100", "u5000", "u1440", "\"123 Main St\"", "\"Test property\""],
        landlordAddress);

      // Try to create maintenance request as tenant (should fail)
      const result = simnet.callPublicFn(
        contractName,
        "create-maintenance-request",
        ["u1", "u1", "\"Unauthorized request\"", "u2", "u250"],
        tenantAddress
      );

      expect(result.result).toContain("(err u100)"); // err-owner-only
    });

    it("should reject invalid maintenance request types", () => {
      simnet.callPublicFn(contractName, "list-property",
        ["u100", "u5000", "u1440", "\"123 Main St\"", "\"Test property\""],
        landlordAddress);

      const result = simnet.callPublicFn(
        contractName,
        "create-maintenance-request",
        ["u1", "u99", "\"Invalid type\"", "u2", "u250"], // invalid request type
        landlordAddress
      );

      expect(result.result).toContain("(err u117)"); // err-invalid-request-type
    });

    it("should reject unauthorized contractors", () => {
      simnet.callPublicFn(contractName, "list-property",
        ["u100", "u5000", "u1440", "\"123 Main St\"", "\"Test property\""],
        landlordAddress);
      
      simnet.callPublicFn(contractName, "create-maintenance-request",
        ["u1", "u1", "\"Leaky faucet\"", "u2", "u250"], landlordAddress);

      // Try to assign unauthorized contractor
      const result = simnet.callPublicFn(
        contractName,
        "assign-contractor", 
        ["u1", tenantAddress], // tenant is not authorized contractor
        landlordAddress
      );

      expect(result.result).toContain("(err u118)"); // err-not-contractor
    });
  });
});
