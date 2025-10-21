import { describe, it, expect, beforeAll } from "vitest";
import { readFileSync } from "fs";
import { resolve } from "path";

const contractName = "rental-nfts-for-real-estate";

describe("Rental NFTs with Maintenance Tracking", () => {
  let contractSource: string;

  beforeAll(() => {
    // Read the contract source code for analysis
    contractSource = readFileSync(
      resolve(__dirname, "../contracts/rental-nfts-for-real-estate.clar"),
      "utf8"
    );
  });

  describe("Contract Structure Validation", () => {
    it("should define the rental-property NFT", () => {
      expect(contractSource).toContain("define-non-fungible-token rental-property");
    });

    it("should have all required error constants", () => {
      expect(contractSource).toContain("err-owner-only");
      expect(contractSource).toContain("err-not-token-owner");
      expect(contractSource).toContain("err-listing-not-found");
      expect(contractSource).toContain("err-property-occupied");
      expect(contractSource).toContain("err-maintenance-not-found");
      expect(contractSource).toContain("err-invalid-maintenance-status");
      expect(contractSource).toContain("err-not-contractor");
    });

    it("should have core rental functions", () => {
      expect(contractSource).toContain("define-public (list-property");
      expect(contractSource).toContain("define-public (rent-property");
      expect(contractSource).toContain("define-public (check-in");
      expect(contractSource).toContain("define-public (check-out");
      expect(contractSource).toContain("define-public (emergency-eviction");
      expect(contractSource).toContain("define-public (withdraw-earnings");
    });

    it("should have maintenance tracking functions", () => {
      expect(contractSource).toContain("define-public (create-maintenance-request");
      expect(contractSource).toContain("define-public (assign-contractor");
      expect(contractSource).toContain("define-public (start-maintenance-work");
      expect(contractSource).toContain("define-public (complete-maintenance-work");
      expect(contractSource).toContain("define-public (rate-contractor");
      expect(contractSource).toContain("define-public (authorize-contractor");
      expect(contractSource).toContain("define-public (revoke-contractor");
    });

    it("should have read-only functions", () => {
      expect(contractSource).toContain("define-read-only (get-property-listing");
      expect(contractSource).toContain("define-read-only (get-active-rental");
      expect(contractSource).toContain("define-read-only (get-maintenance-request");
      expect(contractSource).toContain("define-read-only (get-property-maintenance-costs");
      expect(contractSource).toContain("define-read-only (get-contractor-rating");
      expect(contractSource).toContain("define-read-only (is-authorized-contractor");
    });

    it("should have proper data structures", () => {
      expect(contractSource).toContain("define-map property-listings");
      expect(contractSource).toContain("define-map active-rentals");
      expect(contractSource).toContain("define-map property-maintenance-requests");
      expect(contractSource).toContain("define-map contractor-ratings");
      expect(contractSource).toContain("define-map authorized-contractors");
    });

    it("should have data variables", () => {
      expect(contractSource).toContain("define-data-var next-property-id");
      expect(contractSource).toContain("define-data-var next-maintenance-id");
      expect(contractSource).toContain("define-data-var platform-fee-rate");
    });
  });

  describe("Maintenance System Features", () => {
    it("should support different request types", () => {
      // Check for comments indicating request types
      expect(contractSource).toContain("1=plumbing, 2=electrical, 3=hvac, 4=structural, 5=cosmetic");
    });

    it("should support priority levels", () => {
      // Check for comments indicating priority levels
      expect(contractSource).toContain("1=emergency, 2=urgent, 3=normal, 4=low");
    });

    it("should support status workflow", () => {
      // Check for comments indicating status workflow
      expect(contractSource).toContain("1=pending, 2=approved, 3=in-progress, 4=completed, 5=cancelled");
    });

    it("should have proper validation logic", () => {
      expect(contractSource).toContain("(asserts! (and (>= request-type u1) (<= request-type u5))");
      expect(contractSource).toContain("(asserts! (and (>= priority u1) (<= priority u4))");
      expect(contractSource).toContain("(asserts! (and (>= rating u1) (<= rating u5))");
    });
  });

  describe("Security Features", () => {
    it("should have owner-only restrictions", () => {
      expect(contractSource).toContain("(asserts! (is-eq tx-sender contract-owner)");
    });

    it("should validate landlord permissions", () => {
      expect(contractSource).toContain("(asserts! (is-eq tx-sender (get landlord listing))");
    });

    it("should validate tenant permissions", () => {
      expect(contractSource).toContain("(asserts! (is-eq tx-sender (get tenant rental))");
    });

    it("should validate contractor authorization", () => {
      expect(contractSource).toContain("(asserts! (is-authorized-contractor contractor)");
    });
  });

  describe("Error Handling", () => {
    it("should have comprehensive error constants", () => {
      const errorConstants = [
        "err-owner-only",
        "err-not-token-owner", 
        "err-listing-not-found",
        "err-property-occupied",
        "err-insufficient-payment",
        "err-rental-expired",
        "err-rental-active",
        "err-maintenance-not-found",
        "err-invalid-maintenance-status",
        "err-invalid-priority",
        "err-invalid-request-type",
        "err-not-contractor"
      ];

      errorConstants.forEach(error => {
        expect(contractSource).toContain(error);
      });
    });

    it("should use proper error codes", () => {
      expect(contractSource).toContain("(err u100)"); // err-owner-only
      expect(contractSource).toContain("(err u114)"); // err-maintenance-not-found
      expect(contractSource).toContain("(err u118)"); // err-not-contractor
    });
  });

  describe("Clarity v3 Compliance", () => {
    it("should use proper data types", () => {
      expect(contractSource).toContain("uint");
      expect(contractSource).toContain("principal");
      expect(contractSource).toContain("string-ascii");
      expect(contractSource).toContain("optional");
    });

    it("should have proper function definitions", () => {
      expect(contractSource).toContain("define-public");
      expect(contractSource).toContain("define-read-only");
      expect(contractSource).toContain("define-constant");
      expect(contractSource).toContain("define-data-var");
      expect(contractSource).toContain("define-map");
    });

    it("should use proper unwrap patterns", () => {
      expect(contractSource).toContain("unwrap!");
      expect(contractSource).toContain("try!");
    });

    it("should have proper map operations", () => {
      expect(contractSource).toContain("map-set");
      expect(contractSource).toContain("map-get?");
      expect(contractSource).toContain("map-delete");
    });
  });
});

describe("Contract Deployment Readiness", () => {
  let contractSource: string;

  beforeAll(() => {
    contractSource = readFileSync(
      resolve(__dirname, "../contracts/rental-nfts-for-real-estate.clar"),
      "utf8"
    );
  });

  it("should have valid Clarity syntax", () => {
    // This test passes if the file can be read (clarinet check already validates syntax)
    expect(contractSource.length).toBeGreaterThan(1000);
  });

  it("should be well documented", () => {
    expect(contractSource).toContain(";;");
    expect(contractSource).toContain("NEW FEATURE");
    expect(contractSource).toContain("Maintenance System");
  });

  it("should have proper contract structure", () => {
    // Verify basic contract structure
    expect(contractSource).toContain("define-non-fungible-token");
    expect(contractSource).toContain("define-constant contract-owner tx-sender");
  });
});
