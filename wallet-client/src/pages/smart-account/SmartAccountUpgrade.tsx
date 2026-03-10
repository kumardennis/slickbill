import { createEvmSmartAccount, getCurrentUser } from "@coinbase/cdp-core";

export const UpgradeToSmartAccount = () => {
  const handleUpgrade = async () => {
    const user = await getCurrentUser();

    // Check if user already has a smart account
    if (!user?.evmSmartAccountObjects?.length) {
      // Create a Smart Account (will use existing EOA as owner)
      const smartAccountAddress = await createEvmSmartAccount();
      console.log("Created Smart Account:", smartAccountAddress);

      // User object is automatically updated
      const updatedUser = await getCurrentUser();
      console.log(
        "Smart Account:",
        updatedUser?.evmSmartAccountObjects?.[0]?.address
      );
      console.log("EOA (owner):", updatedUser?.evmAccountObjects?.[0]?.address);
    }
  };

  return <button onClick={handleUpgrade}>Upgrade to Smart Account</button>;
};
