"use client";

import { useEffect, useMemo, useState } from "react";
import { formatEther } from "viem";
import { useAccount, useBlockNumber, usePublicClient } from "wagmi";
import { useScaffoldReadContract } from "~~/hooks/scaffold-eth";

const GRACE_PERIOD_SECONDS = 24 * 60 * 60;

function formatCountdown(totalSeconds: number) {
  const clampedSeconds = Math.max(0, Math.floor(totalSeconds));
  const hours = Math.floor(clampedSeconds / 3600);
  const minutes = Math.floor((clampedSeconds % 3600) / 60);
  const hourLabel = hours === 1 ? "hour" : "hours";
  const minuteLabel = minutes === 1 ? "min" : "mins";
  return `${hours} ${hourLabel} ${minutes} ${minuteLabel} remaining`;
}

export default function ProtectionDashboard() {
  const { address } = useAccount();
  const client = usePublicClient();
  const { data: blockNumber } = useBlockNumber({ watch: true });
  const [blockTimestamp, setBlockTimestamp] = useState<number | null>(null);

  useEffect(() => {
    if (!client || !blockNumber) return;
    let isStale = false;
    client
      .getBlock({ blockNumber })
      .then((block: any) => {
        if (!isStale) setBlockTimestamp(Number(block.timestamp));
      })
      .catch(() => {});
    return () => {
      isStale = true;
    };
  }, [client, blockNumber]);

  const { data: healthFactor } = useScaffoldReadContract({
    contractName: "Lending",
    functionName: "getHealthFactor",
    args: [address] as any,
  });

  const { data: atRiskSince } = useScaffoldReadContract({
    contractName: "Lending",
    functionName: "s_atRiskSince",
    args: [address] as any,
  });

  const { statusLabel, statusTone, countdownText, healthFactorDisplay } = useMemo(() => {
    const hf = healthFactor ?? 0n;
    const hfDisplay = healthFactor ? Number(formatEther(healthFactor)).toFixed(2) : "—";

    if (!address) {
      return {
        statusLabel: "Connect a wallet to view protection status",
        statusTone: "neutral",
        countdownText: "",
        healthFactorDisplay: hfDisplay,
      } as const;
    }

    if (hf >= 1_000_000_000_000_000_000n) {
      return {
        statusLabel: "Equity Secure",
        statusTone: "success",
        countdownText: "",
        healthFactorDisplay: hfDisplay,
      } as const;
    }

    const riskStart = atRiskSince ? Number(atRiskSince) : 0;
    if (riskStart === 0 || blockTimestamp === null) {
      return {
        statusLabel: "Safety Net Active",
        statusTone: "warning",
        countdownText: "Starting protection window…",
        healthFactorDisplay: hfDisplay,
      } as const;
    }

    const protectionEndsAt = riskStart + GRACE_PERIOD_SECONDS;
    if (blockTimestamp < protectionEndsAt) {
      return {
        statusLabel: "Safety Net Active",
        statusTone: "warning",
        countdownText: formatCountdown(protectionEndsAt - blockTimestamp),
        healthFactorDisplay: hfDisplay,
      } as const;
    }

    return {
      statusLabel: "Protection Expired",
      statusTone: "error",
      countdownText: "Liquidation is now possible",
      healthFactorDisplay: hfDisplay,
    } as const;
  }, [address, atRiskSince, blockTimestamp, healthFactor]);

  const toneClasses =
    statusTone === "success"
      ? "border-[#00FF7F] text-[#008000]"
      : statusTone === "warning"
        ? "border-[#FFB74D] text-[#FF8C00]"
        : statusTone === "error"
          ? "border-red-800 text-red-800"
          : "border-base-300 text-base-content";

  return (
    <div className={`bg-base-100 w-[420px] border shadow-md rounded-xl p-6 ${toneClasses}`}>
      <div className="flex items-start justify-between gap-4">
        <div className="flex flex-col">
          <div className="text-sm font-semibold opacity-80">Protection Dashboard</div>
          <div className="text-xl font-bold">{statusLabel}</div>
        </div>
        <div className="text-right">
          <div className="text-xs opacity-70">Health Factor</div>
          <div className="text-lg font-semibold">{healthFactorDisplay}</div>
        </div>
      </div>
      {countdownText ? <div className="mt-3 text-sm">{countdownText}</div> : null}
    </div>
  );
}
