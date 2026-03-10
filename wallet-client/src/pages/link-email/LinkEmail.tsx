import {
  useLinkEmail,
  useVerifyEmailOTP,
  useCurrentUser,
} from "@coinbase/cdp-hooks";
import { useState } from "react";

export const LinkEmail = () => {
  const { linkEmail } = useLinkEmail();
  const { verifyEmailOTP } = useVerifyEmailOTP();
  const { currentUser } = useCurrentUser();
  const [flowId, setFlowId] = useState("");

  const handleLinkEmail = async (email: string) => {
    if (!currentUser) {
      console.error("User must be signed in first");
      return;
    }

    try {
      // Initiate email linking
      const result = await linkEmail(email);
      setFlowId(result.flowId);

      console.log("OTP sent to email, flowId:", flowId);

      // In a real application, you would prompt the user for the OTP
      const otp = "123456";

      // Verify the OTP to complete linking
      await verifyEmailOTP({
        flowId: result.flowId,
        otp,
      });

      console.log("Email linked successfully!");
    } catch (error) {
      console.error("Failed to link email:", error);
    }
  };

  return (
    <button
      onClick={() => handleLinkEmail("denniskumar299@gmail.com")}
      disabled={!currentUser}
    >
      Link Email
    </button>
  );
};
