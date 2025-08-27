
//nvm install --lts 
//npm install -g pnpm
// pnpm add node
import { 
    MY_CONTRACT_ADDRESS, 
    USDC_CONTRACT_ADDRESS, 
    WETH_CONTRACT_ADDRESS, 
    MY_CONTRACT_ABI, 
    APPROVE_ABI, 
    NETWORK } from "./static-ts";
import {
    defineChain,
    parseEther,
    createWalletClient,
    custom,
    createPublicClient,
    formatEther,
    WalletClient,
    PublicClient,
    Address,
    Chain,
    getAddress,
    getContract
} from "viem";

import "viem/window"
import { mainnet, sepolia, optimism, arbitrum } from 'viem/chains';


const supportedChains: Record<number, Chain> = {
    1: mainnet,
    11155111: sepolia,
    10: optimism,
    42161: arbitrum,
    // Add other chains as needed
};

interface ChainInfo {
    name: string;
    blockExplorer: string;
}

const supportedChainInfo: Record<string, ChainInfo> = {
    "mainnet": {
        name: 'Ethereum Mainnet',
        blockExplorer: 'https://etherscan.io/address/'
    },
    "sepolia": {
        name: 'Sepolia Testnet',
        blockExplorer: 'https://sepolia.etherscan.io/address/'
    },
    "optimism": {
        name: 'Optimism',
        blockExplorer: 'https://optimistic.etherscan.io'
    },
    "arbitrum": {
        name: 'Arbitrum One',
        blockExplorer: 'https://arbiscan.io'
    },
    "polygon": {
        name: 'Polygon',
        blockExplorer: 'https://polygonscan.com'
    },
    "bnb": {
        name: 'BNB Chain',
        blockExplorer: 'https://bscscan.com'
    }
};



const contractAddress: Address = getAddress(MY_CONTRACT_ABI);
const abi = MY_CONTRACT_ABI;
const network:string = NETWORK;

const KEY_CONNECTED = "idex_connected";


//ConenctWallet
const chainBadge  = document.getElementById("chain") as HTMLSpanElement;
const btnConnect  = document.getElementById("btnConnect") as HTMLButtonElement;


//Key Performance Indicator
const kpiUsdc = document.getElementById ("kpiUsdc") as HTMLDivElement;
const kpiEth = document.getElementById ("kpiEth") as HTMLDivElement;
const kpiSwapFees = document.getElementById ("kpiSwapFees") as HTMLDivElement;
const kpiPrice = document.getElementById ("kpiPrice") as HTMLDivElement;
const kpiUelp = document.getElementById ("kpiUelp") as HTMLDivElement;

//Swap
const swapTokenIn = document.getElementById ("swapTokenIn") as HTMLSelectElement;
const swapTokenOut = document.getElementById ("swapTokenOut") as HTMLSelectElement;
const swapAmountIn = document.getElementById ("swapAmountIn") as HTMLInputElement;
const swapSlippage = document.getElementById ("swapSlippage") as HTMLInputElement;
const swapEstimatedOut = document.getElementById ("swapEstimatedOut") as HTMLInputElement;
const swapStatus = document.getElementById ("swapStatus") as HTMLDivElement;
const btnQuote = document.getElementById("btnQuote") as HTMLButtonElement;
const btnSwap = document.getElementById("btnSwap") as HTMLButtonElement;


//Provide Liquidity
const liqUsdc = document.getElementById ("liqUsdc") as HTMLInputElement;
const liqEth = document.getElementById ("liqEth") as HTMLInputElement;
const liqStatus = document.getElementById ("liqStatus") as HTMLDivElement;
const btnProvide =  document.getElementById ("btnProvide") as HTMLButtonElement; 
const btnApproveUsdc =  document.getElementById ("btnApproveUsdc") as HTMLButtonElement;
const btnApproveEth =  document.getElementById ("btnApproveEth") as HTMLButtonElement;

//Withdraw
const wdUelp   = document.getElementById("wdUelp") as HTMLInputElement;
const btnWithdraw = document.getElementById("btnWithdraw") as HTMLButtonElement;
const wdStatus = document.getElementById("wdStatus") as HTMLDivElement;

// Provider Fees
const feeUsdc = document.getElementById("feeUsdc") as HTMLInputElement;
const feeEth = document.getElementById("feeEth") as HTMLInputElement;
const btnRefreshFees = document.getElementById("btnRefreshFees") as HTMLButtonElement;
const btnClaimFees = document.getElementById("btnClaimFees") as HTMLButtonElement;
const feeStatus = document.getElementById("feeStatus") as HTMLDivElement;

// AdminPanel
const admSwapFee   = document.getElementById("admSwapFee") as HTMLInputElement;
const admProtFee   = document.getElementById("admProtFee") as HTMLInputElement;
const admMinPpm    = document.getElementById("admMinPpm") as HTMLInputElement;
const admCooldown  = document.getElementById("admCooldown") as HTMLInputElement;
const btnLoadParams = document.getElementById("btnLoadParams") as HTMLButtonElement;
const btnSaveParams = document.getElementById("btnSaveParams") as HTMLButtonElement;
const admPrAddr     = document.getElementById("admPrAddr") as HTMLInputElement;
const admRescueAddr = document.getElementById("admRescueAddr") as HTMLInputElement;
const admRescueAmt  = document.getElementById("admRescueAmt") as HTMLInputElement;
const btnSetPr  = document.getElementById("btnSetPr") as HTMLButtonElement;
const btnRescue = document.getElementById("btnRescue") as HTMLButtonElement;
const admStatus = document.getElementById("admStatus") as HTMLDivElement;

// Stats
const stSwap = document.getElementById("stSwap") as HTMLSpanElement;
const stProt = document.getElementById("stProt") as HTMLSpanElement;
const stMin  = document.getElementById("stMin") as HTMLSpanElement;
const stCd   = document.getElementById("stCd") as HTMLSpanElement;
const stPr   = document.getElementById("stPr") as HTMLSpanElement;




let walletClient: WalletClient | null = null;
let publicClient: PublicClient | null = null;
let connectedAccount: `0x${string}` | null = null;

// /** generic function */
async function readContract<T>(funName: string, requiresAccount: boolean): Promise<T> {
    await setUpPublicClients();
    if (requiresAccount)
        await setUpWalletClients();

    return await publicClient!.readContract({
        address: contractAddress,
        abi: abi,
        functionName: funName,
        ...(requiresAccount && { account: connectedAccount! })
        // in the above, ... (spread operator) in this context is used for conditionally including properties in an object
    }).then((result) => result as T)
        .catch((error) => {
            const err = error as { shortMessage?: string, details?: string };
            console.log (err);
            return undefined as T;
    });
}

async function writeContract(funName: string, requiresValue: boolean = false, value: bigint = 0n, args: any[] = []): Promise<`0x${string}`> {
    await setUpPublicClients();
    await setUpWalletClients();

    const currentChain: Chain = await getCurrentChain(publicClient!);
    const { request } = await publicClient!.simulateContract({
        address: contractAddress,
        abi: abi,
        functionName: funName,
        args: args,
        chain: currentChain,
        account: connectedAccount,
        ...(requiresValue && { value: value })
    }).catch(error => {
        const reason = error?.walk?.()?.shortMessage || "Read failed";
        console.log (reason);
    });
    return await walletClient!.writeContract(request) as `0x${string}`;
}

// /** getters */
// async function getCurrentChainID(): Promise<number> {
//     if (typeof window.ethereum === "undefined") {
//         updateStatus(`<span class="error-bold-italic">Please install an Ethereum-compatible wallet (such as MetaMask or Coinbase Wallet) to fund panda preservation.</span>`);
//         throw new Error("Wallet not installed");
//     }
//     const chainIdHex = await window.ethereum!.request({ method: 'eth_chainId' });
//     return parseInt(chainIdHex, 16);
// }

async function getCurrentChain(client: PublicClient | WalletClient): Promise<Chain> {
    const chainId = await client.getChainId();

    if (supportedChains[chainId]) {
        return supportedChains[chainId];
    }

    // Fallback for unsupported chains
    return {
        id: chainId,
        name: `Unknown Chain (${chainId})`,
        nativeCurrency: {
            name: 'Ether',
            symbol: 'ETH',
            decimals: 18,
        },
        rpcUrls: {
            default: { http: [''] },
            public: { http: [''] }
        },
        testnet: true
    };
}

// async function getNumberOfFunders(): Promise<number> {
//     if (!publicClient) {
//         publicClient = await createPublicClient({ transport: custom(window.ethereum!!) });
//     }
//     const currentChain = await getCurrentChain(publicClient);
//     const nFunders: number = await readContract<number>("getNumberOfFunders", false) as number;
//     return nFunders;
// }

// async function getContractBalance(): Promise<bigint> {
//     setUpPublicClients();
//     return await publicClient!.getBalance({
//         address: contractAddress
//     }) as bigint;
// }

// async function getContribution(): Promise<number> {
//     return await readContract<number>("getMyContribution", true) as number;;
// }

/** setters */

async function setUpWalletClients(): Promise<void> {
    if (!walletClient)
        walletClient = createWalletClient({ transport: custom(window.ethereum!) });
    if (!connectedAccount)
        [connectedAccount] = await walletClient.requestAddresses();
}

async function setUpPublicClients(): Promise<void> {
    if (!publicClient)
        publicClient = createPublicClient({ transport: custom(window.ethereum!) });
}


// async function disconnect(): Promise<void> {
//     connectedAccount = null;
//     walletClient = null;
//     connectWalletBtn.innerText = "Connect Wallet";
//     updateStatus("Not connected");
// }

async function connect(): Promise<void> {
    walletClient = await createWalletClient({ transport: custom(window.ethereum!) });
    const [account] = await walletClient.requestAddresses();
    connectedAccount = account;
    btnConnect.innerText = account.slice(0, 6) + "..." + account.slice(-4);
    chainBadge.innerText =  supportedChainInfo[network].name;
    localStorage.setItem(KEY_CONNECTED, "1");
    kpiFetchFeed ();
}

async function restoreConnection ():Promise <void> {
    if (localStorage.getItem(KEY_CONNECTED) !== "1") return;
    walletClient = await createWalletClient({ transport: custom(window.ethereum!) });

    const addrs = await walletClient.getAddresses(); 
    if (addrs.length === 0) {
        localStorage.removeItem(KEY_CONNECTED);
        return;
    }
    connectedAccount = addrs[0];
    btnConnect.innerText = connectedAccount.slice(0, 6) + "..." + connectedAccount.slice(-4);
    chainBadge.innerText = supportedChainInfo[network].name;
}

async function kpiFetchFeed(): Promise<void> {
    const [usdcReserve, ethReserve] = await readContract<[bigint, bigint]>(
      "getReserves",
      false
    ) as [bigint, bigint];
  
    const [usdcFees, ethFees] = await readContract<[bigint, bigint]>(
      "getAccruedSweepFees",
      false
    ) as [bigint, bigint];
  
    const exchangeRate = await readContract<bigint>(
      "getPoolExchangeRate",
      false
    ) as bigint | undefined;;
  
    kpiUsdc.innerText = formatUsdc(usdcReserve);
    kpiEth.innerText = formatEther(ethReserve);
    kpiSwapFees.innerText = `${formatUsdc(usdcFees)} / ${formatEther(ethFees)}`;
    if (exchangeRate !== undefined)
            kpiPrice.innerText = formatEther(exchangeRate);
  
    if (localStorage.getItem(KEY_CONNECTED) === "1" && walletClient != null) {
      const addrs = await walletClient.getAddresses();
      if (addrs.length > 0) {
        const yourUelp = await readContract<bigint>(
          "getLPBalanceByProvider",
          true
        ) as bigint;
        kpiUelp.innerText = formatEther(yourUelp);
      }
    }
}


async function approveETH ():Promise <void> {
    const ethAmnt = parseEther(liqEth.value ) as bigint;
    const hash = await approveToken (WETH_CONTRACT_ADDRESS, ethAmnt) as `0x${string}`;
}

async function approveUSDC ():Promise <void> {
    const usdcAmnt = parseUsdc (liqUsdc.value ) as bigint;
    const hash = await approveToken (USDC_CONTRACT_ADDRESS, usdcAmnt) as `0x${string}`;
}

async function approveToken(tokenAddress:`0x${string}`, amount: bigint): Promise<`0x${string}`> {
    await setUpPublicClients();
    await setUpWalletClients();
    const currentChain: Chain = await getCurrentChain(publicClient!);
    const { request } = await publicClient!.simulateContract({
            address: tokenAddress,  
            abi: APPROVE_ABI,          
            functionName: "approve",
            args: [contractAddress, amount],
            chain: currentChain,
            account: connectedAccount
    });
    return await walletClient!.writeContract(request) as `0x${string}`;
}


function parseUsdc(input: string): bigint {
    const value = BigInt(input);
    return value * 10n ** 6n;
}
  

function formatUsdc(amount: bigint): string {
    const divisor = 10n ** 6n;
    const whole = amount / divisor;
    const fraction = amount % divisor;
  
    const fractionStr = fraction.toString().padStart(6, "0");
  
    const trimmedFraction = fractionStr.replace(/0+$/, "");
  
    return trimmedFraction.length > 0
      ? `${whole.toString()}.${trimmedFraction}`
      : whole.toString();
  }
  

// function setUp(): void {
//     setProgress();
//     setNFunders();
//     setContribution();
// }

// async function setProgress(): Promise<void> {
//     if (!publicClient) {
//         publicClient = await createPublicClient({ transport: custom(window.ethereum!) });
//     }
//     publicClient = createPublicClient({ transport: custom(window.ethereum!) });
//     const balance = await getContractBalance();
//     totalRaised.innerText = `Total Raised: ${formatEther(balance)} ETH`;
//     updateProgressBar(Math.min((Number(formatEther(balance)) / 100) * 100, 100));
// }

// async function setNFunders(): Promise<void> {

//     const nFunders: number = await getNumberOfFunders();
//     totalFunders.innerText = `${nFunders}`;
// }

// async function setContribution(): Promise<void> {
//     if (!walletClient)
//         return;
//     const contribution: number = await getContribution();
//     console.log("Your contribution:", contribution);
//     yourContribution.innerText = `${formatEther(contribution)}`;
// }

/** Misc */

// function updateProgressBar(progressPercentage: number) {
//     progressBar.style.width = `${progressPercentage}%`;
//     progressBar.style.background = `
//         linear-gradient(90deg,
//         #ff4d4d 0%,
//         #ffcc00 30%,
//         #00cc66 70%
//         )
//     `;
//     progressBar.style.backgroundSize = `${progressPercentage}% 100%`;
// }

// function updateStatus(msg: string): void {
//     interactionStatus.innerHTML = msg;
//     highlightStatusElement()
// }

// function highlightStatusElement(): void {
//     // 1. Make sure the element is focusable
//     interactionStatus.tabIndex = -1;

//     // 2. Smooth scroll to the element
//     interactionStatus.scrollIntoView({
//         behavior: 'smooth',
//         block: 'center' // Scrolls to center the element vertically
//     });

//     // 3. Add glowing animation
//     interactionStatus.classList.add('glowing-alert');

//     // 4. Remove the glow after animation completes
//     setTimeout(() => {
//         interactionStatus.classList.remove('glowing-alert');
//     }, 3000); // Matches CSS animation duration

//     // 5. Focus for accessibility
//     interactionStatus.focus();
// }


/** Cores */
// async function fund(): Promise<void> {
//     if (typeof window.ethereum == "undefined") {
//         updateStatus(`<span class="error-bold-italic">Please install an Ethereum-compatible wallet (such as MetaMask or Coinbase Wallet) to fund panda preservation.</span>`);
//         return;
//     }
//     let ethAmount: number = parseFloat(fundAmount.value);
//     if (ethAmount < minimum_fundable) {
//         updateStatus(`<span class="error-bold-italic">Please enter at least ${minimum_fundable} ETH to fund.</span>`);
//         return;
//     }
//     const amountInWei = parseEther(fundAmount.value);
//     const hash = await writeContract("fund", true, amountInWei, []);
//     const receipt = await publicClient!.waitForTransactionReceipt({ hash });
//     let msg: string = `Thank you for your donation of <strong>${ethAmount} ETH</strong>! Your support means a lot.`;
//     if (receipt.status !== 'success')
//         msg = "Transaction failed. Please try again.";
//     else
//         setUp();
//     updateStatus(msg);
// }

// async function withdraw(): Promise<void> {
//     const hash = await writeContract("withdraw", false, 0n, []);
//     const receipt = await publicClient!.waitForTransactionReceipt({ hash });
//     let msg: string = "Funds withdrawn successfully!";
//     if (receipt.status !== 'success')
//         msg = "Transaction failed";
//     else
//         setUp();
//     updateStatus(msg);

// }

// async function main(): Promise<void> {
//     heroSpan.innerHTML =  `Powered By Ethereum ${supportedChainInfo[network].name}`;
//     chainNameSpan.innerHTML = supportedChainInfo[network].name;
//     contractAddressSpan.innerHTML = `<a href="${supportedChainInfo[network].blockExplorer}/${contractAddress}" 
//      target="_blank" 
//      rel="noopener noreferrer"
//      class="contract-link"> ${contractAddress}</a>`;


//     if (typeof window.ethereum === 'undefined') {
//         updateStatus(`<span class="error-bold-italic">Please install an Ethereum-compatible wallet (such as MetaMask or Coinbase Wallet) to fund panda preservation.</span>`);
//         return;
//     }
//     setUp();
// }




btnConnect.onclick = connect
btnApproveEth.onclick = approveEth 
btnApproveUsdc.onclick = approveUsdc
// fundBtn.onclick = fund
// withdrawFundsBtn.onclick = withdraw
// main()
restoreConnection();
kpiFetchFeed ();