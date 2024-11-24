"use client";
import { Box, Button, TextField, Typography } from "@mui/material";
import styles from "../../styles/Home.module.css";
import { useStakeContract } from "../../hooks/useContract";
import { useCallback, useEffect, useState } from "react";
import { Pid } from "../../utils";
import { useAccount, useWalletClient } from "wagmi";
import { formatUnits, parseUnits, zeroAddress } from "viem";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import LoadingButton from "@mui/lab/LoadingButton";
import { toast } from "react-toastify";
import { waitForTransactionReceipt } from "viem/actions";

const Home = () => {
  const stakeContract = useStakeContract();
  const { address, isConnected } = useAccount();
  const [stakedAmount, setStakedAmount] = useState("0");
  const [amount, setAmount] = useState("0");
  const [loading, setLoading] = useState(false);
  const { data } = useWalletClient();
  // const updatePool = async () => {
  //   try {
  //     const res = await stakeContract?.write.updatePool([
  //       Pid,
  //       parseUnits('0.001', 18),
  //       100
  //     ])
  //     console.log(res, 'res')
  //   } catch (error) {
  //     console.log(error, 'addPool')
  //   }
  // }

  const handleStake = async () => {
    if (!stakeContract || !data) return;
    try {
      setLoading(true);
      const tx = await stakeContract.write.deposit([], {
        value: parseUnits(amount, 18),
      });
      const res = await waitForTransactionReceipt(data, { hash: tx });
      console.log(res, "tx");
      toast.success("Transaction receipt !");
      setLoading(false);
      getStakedAmount();
    } catch (error) {
      setLoading(false);
      console.log(error, "stake-error");
    }
  };
    const checkPool = async () => {
        const res = await stakeContract?.read.poolLength();
        if ((res as bigint) === BigInt(0)) {
            const aadress0 = '0x0000000000000000000000000000000000000000';
            const res = await stakeContract?.read.addPoll([
              aadress0,
              5,
              10,
              5,
              false,
            ]);
            console.log('res',res);
        }
  }
  const getStakedAmount = useCallback(async () => {
    if (address && stakeContract) {
      // const res = await stakeContract?.read.poolLength();
      try {
        const res = await stakeContract?.read.stakingBalance([Pid, address]);
        setStakedAmount(formatUnits(res as bigint, 18));
      } catch (error) {
          setStakedAmount(formatUnits(BigInt(0), 18));
      }
    }
  }, [stakeContract, address]);

  useEffect(() => {
      if (stakeContract && address) {
          checkPool();
      getStakedAmount();
    }
  }, [stakeContract, address]);

  return (
    <Box
      display={"flex"}
      flexDirection={"column"}
      alignItems={"center"}
      width={"100%"}
    >
      <Typography sx={{ fontSize: "30px", fontWeight: "bold" }}>
        Rcc Stake
      </Typography>
      <Typography sx={{}}>Stake ETH to earn tokens.</Typography>
      {/* <Button onClick={updatePool}>Update</Button> */}
      <Box
        sx={{
          border: "1px solid #eee",
          borderRadius: "12px",
          p: "20px",
          width: "600px",
          mt: "30px",
        }}
      >
        <Box display={"flex"} alignItems={"center"} gap={"5px"} mb="10px">
          <Box>Staked Amount: </Box>
          <Box>{stakedAmount} ETH</Box>
        </Box>
        <TextField
          onChange={(e) => {
            setAmount(e.target.value);
          }}
          sx={{ minWidth: "300px" }}
          label="Amount"
          variant="outlined"
        />
        <Box mt="30px">
          {!isConnected ? (
            <ConnectButton />
          ) : (
            <LoadingButton
              variant="contained"
              loading={loading}
              onClick={handleStake}
            >
              Stake
            </LoadingButton>
          )}
        </Box>
      </Box>
    </Box>
  );
};

export default Home;