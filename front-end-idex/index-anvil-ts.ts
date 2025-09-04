
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
        getContract,
        http // <-- added
    } from "viem";
    

import "viem/window"
import { mainnet, sepolia, optimism, arbitrum, foundry } from 'viem/chains';

const supportedChains: Record<number, Chain> = {
    1: mainnet,
    11155111: sepolia,
    10: optimism,
    42161: arbitrum,
    31337:foundry
    // Add other chains as needed
};


interface ChainInfo {
    name: string;
    blockExplorer: string;
}

const supportedChainInfo: Record<string, ChainInfo> = {
    "anvil": {
        name: 'Anvil',
        blockExplorer: 'https://etherscan.io/address/'
    },
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



const contractAddress: Address = getAddress(MY_CONTRACT_ADDRESS);
const abi = MY_CONTRACT_ABI;
const network:string = NETWORK;

const ANVIL_RPC = "http://127.0.0.1:8545";
const ANVIL_CHAIN_ID_HEX = "0x7A69"; // 31337



const KEY_CONNECTED = "idex_connected";

let poolSeeded = false as boolean;
let pair: Map <string, string>;

let quotedAmount : bigint;

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

const status = document.getElementById ("status") as HTMLDivElement;


//Provide Liquidity
const liqUsdc = document.getElementById ("liqUsdc") as HTMLInputElement;
const liqEth = document.getElementById ("liqEth") as HTMLInputElement;
const btnProvide =  document.getElementById ("btnProvide") as HTMLButtonElement; 
const btnApproveUsdc =  document.getElementById ("btnApproveUsdc") as HTMLButtonElement;
const btnApproveEth =  document.getElementById ("btnApproveEth") as HTMLButtonElement;

//Withdraw
const wdUelp   = document.getElementById("wdUelp") as HTMLInputElement;
const btnWithdraw = document.getElementById("btnWithdraw") as HTMLButtonElement;
//const wdStatus = document.getElementById("wdStatus") as HTMLDivElement;

// Provider Fees
const feeUsdc = document.getElementById("feeUsdc") as HTMLInputElement;
const feeEth = document.getElementById("feeEth") as HTMLInputElement;
const btnRefreshFees = document.getElementById("btnRefreshFees") as HTMLButtonElement;
const btnClaimFees = document.getElementById("btnClaimFees") as HTMLButtonElement;
//const feeStatus = document.getElementById("feeStatus") as HTMLDivElement;


// Stats
// const stSwap = document.getElementById("stSwap") as HTMLSpanElement;
// const stProt = document.getElementById("stProt") as HTMLSpanElement;
// const stMin  = document.getElementById("stMin") as HTMLSpanElement;
// const stCd   = document.getElementById("stCd") as HTMLSpanElement;
// const stPr   = document.getElementById("stPr") as HTMLSpanElement;




let walletClient: WalletClient | null = null;
let publicClient: PublicClient | null = null;
let connectedAccount: `0x${string}` | null = null;

// /** generic function */
async function readContract<T>(funName: string, requiresAccount: boolean, requiresArg: boolean, _args: any[] = []): Promise<T> {
    await setUpPublicClients();
    if (requiresAccount)
        await setUpWalletClients();

    return await publicClient!.readContract({
        address: contractAddress,
        ...(requiresArg && {args:_args}),
        abi: abi,
        functionName: funName,
        ...(requiresAccount && { account: connectedAccount! })
        // in the above, ... (spread operator) in this context is used for conditionally including properties in an object
    }).then((result) => result as T)
        .catch((error) => {
            const err = error as { shortMessage?: string, details?: string };
            if (err.shortMessage) {
                showMessage(err.shortMessage, "err");
            } else {
                showMessage("Unexpected error", "err");
            }
            return undefined as T;
    });
}

async function writeContract(funName: string, args: any[] = []): Promise<`0x${string}` | undefined> {
    await setUpPublicClients();
    await setUpWalletClients();
    try 
    {
        const currentChain: Chain = await getCurrentChain(publicClient!);
        const { request } = await publicClient!.simulateContract({
            address: contractAddress,
            abi: abi,
            functionName: funName,
            args: args,
            chain: currentChain,
            account: connectedAccount,
        });
        return await walletClient!.writeContract(request) as `0x${string}`;     
    }
    catch (error:any) {
    
        showMessage(error.cause.metaMessages [0], "err");

        if (error?.cause?.metaMessages) {
            const details = error.cause.metaMessages.join("\n");
            showMessage(error.cause.metaMessages [0] + error.cause.metaMessages [1], "err");
        }  else if (error?.shortMessage) {
            showMessage(error.shortMessage, "err");
        } else {
            showMessage("Unexpected error occurred", "err");
        }
        throw error;
    }
}

async function getCurrentChain(_client: PublicClient | WalletClient): Promise<Chain> {
    // Hard lock to Anvil only
    const chainId = await _client.getChainId().catch(() => foundry.id);
    if (chainId !== foundry.id) {
        throw new Error(`This app only supports Anvil (chainId 31337). Detected: ${chainId}`);
    }
    return foundry;
}

async function setUpPublicClients(): Promise<void> {
    if (!publicClient) {
        publicClient = createPublicClient({
            chain: foundry,
            transport: http(ANVIL_RPC),
        });
    }
}

async function connect(): Promise<void> {
    walletClient = await createWalletClient({ transport: custom(window.ethereum!) });
    const [account] = await walletClient.requestAddresses();
    connectedAccount = account;
    btnConnect.innerText = account.slice(0, 6) + "..." + account.slice(-4);
    chainBadge.innerText =  supportedChainInfo[network].name;
    localStorage.setItem(KEY_CONNECTED, "1");
    initFetchFeed ();
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

async function initFetchFeed(): Promise<void> {
    const [usdcReserve, ethReserve] = await readContract<[bigint, bigint]>(
      "getReserves",
      false,
      false
    ) as [bigint, bigint];
  
    const [usdcFees, ethFees] = await readContract<[bigint, bigint]>(
      "getAccruedSweepFees",
      false,
      false
    ) as [bigint, bigint];
  
    const exchangeRate = await readContract<bigint>(
      "getPoolExchangeRate",
      false,
      false
    ) as bigint | undefined;;
  
    kpiUsdc.innerText = setPrecision (formatUsdc (usdcReserve));
    kpiEth.innerText = setPrecision (formatEther(ethReserve));
    kpiSwapFees.innerText = `${setPrecision (formatUsdc(usdcFees))} / ${setPrecision (formatEther(ethFees))}`;
    if (exchangeRate !== undefined)
            kpiPrice.innerText = setPrecision (exchangeRate.toString());
  
    if (localStorage.getItem(KEY_CONNECTED) === "1" && walletClient != null) {
     if (!poolSeeded)
        showMessage ("the pool is not seeded yet!", "wrn");
     else {
        const addrs = await walletClient.getAddresses();
        if (addrs.length > 0) {
            const yourUelp = await readContract<bigint>(
            "getLPBalanceByProvider",
            true,
            false
            ) as bigint;
            kpiUelp.innerText = setPrecision (formatEther(yourUelp));
        }
      }
    }

    refreshProviderFees ();
}

async function refreshProviderFees () : Promise <void> {
    const [usdcFeesR, ethFeesR] = await readContract<[bigint, bigint]>(
        "getAccruedProtocolFees",
        true,
        false
      ) as [bigint, bigint];
    
    feeUsdc.value = formatUsdc (usdcFeesR);
    feeEth.value = formatEther (ethFeesR);
}

function setPrecision (numStr:string) {
    return parseFloat (numStr).toFixed (2).toString ();
}

async function setUpWalletClients(): Promise<void> {
    if (!walletClient) {
        walletClient = createWalletClient({
            chain: foundry,
            transport: custom(window.ethereum!),
        });
    }

    // Always request MetaMask to add Anvil (31337) and then switch
    await (walletClient as any).request?.({
        method: "wallet_addEthereumChain",
        params: [{
            chainId: ANVIL_CHAIN_ID_HEX, // "0x7A69"
            chainName: "Anvil (Foundry)",
            nativeCurrency: { name: "Anvil ETH", symbol: "ETH", decimals: 18 },
            rpcUrls: [ANVIL_RPC],        // "http://127.0.0.1:8545"
            blockExplorerUrls: []
        }]
    });

    // @ts-ignore
    await walletClient.switchChain({ id: foundry.id });

    if (!connectedAccount) {
        [connectedAccount] = await walletClient.requestAddresses();
    }
}


function setProviderBtn () {
    btnProvide.innerText = (!poolSeeded? "Seed": "Depost") as string; 
}

async function provideLiquidity (): Promise <void> {
    hideLiqStatus ();
    const usdcAmnt = parseUsdc (liqUsdc.value ) as bigint;
    const ethAmnt = parseEther (liqEth.value ) as bigint;
    if (usdcAmnt <= 0 || ethAmnt <=0){
        showMessage ("Both amount has to be non-zero","wrn");
        return;
    }

    await setUpWalletClients ();
    await setUpPublicClients ();
        
    let providerFun = (!poolSeeded ? "seedDex" : "supplyLiquidity") as string; 

    const usdcApproved = await readContract ("isApproved",true,true, ["USDC",usdcAmnt ]) as boolean;
    const ethApproved = await readContract ("isApproved",true,true, ["WETH", ethAmnt ]) as boolean;
    if (usdcApproved && ethApproved) {
        const hash = await writeContract (providerFun, [usdcAmnt, ethAmnt]);
        
        let prefix:string = !poolSeeded ? "Seeding " : "Depositing " ;
        showMessage (prefix+ liqUsdc.value + " USDC and "+ liqEth.value + " ETH ...", "ok");

        
        const receipt = await publicClient!.waitForTransactionReceipt({ hash });
        

        let msg:string = !poolSeeded ? "Seeding Successful!" : "Depost Successful!";
        if (receipt.status !== 'success')
             msg = !poolSeeded ? "Seeding Failed!" : "Depost Failed!";
        else 
            poolSeeded = true;
        showMessage (msg, receipt.status !== 'success'? "err" : "ok");
    }
    else {
        showMessage("Please approve both USDC and ETH", "wrn");
    }
    initFetchFeed ();
    setProviderBtn ();
}



async function approveETH ():Promise <void> {
    hideLiqStatus ();
    const ethAmnt = parseEther(liqEth.value ) as bigint;
    if (ethAmnt <=0){
        showMessage ("ETH amount has to be non-zero for approval", "wrn");
        return;
    }
    
    await setUpWalletClients ();

    const hash = await approveToken (WETH_CONTRACT_ADDRESS, ethAmnt) as `0x${string}`;
    showMessage ("Approving "+liqEth.value+" ETH ... ", "ok");
    const receipt = await publicClient!.waitForTransactionReceipt({ hash });
    let msg:string =  liqEth.value+" ETH has been approved!";
    if (receipt.status !== 'success')
        msg = "ETH approval failed!";
    showMessage (msg, receipt.status !== 'success'? "err" : "ok");
}

async function approveUSDC ():Promise <void> {
    const usdcAmnt = parseUsdc (liqUsdc.value ) as bigint;

    if (usdcAmnt <=0){
        showMessage ("USDC amount has to be non-zero for approval", "wrn");
        return;
    }
    await setUpWalletClients ();

    const hash = await approveToken (USDC_CONTRACT_ADDRESS, usdcAmnt) as `0x${string}`;
    showMessage ("Approving "+liqUsdc.value+" USDC ... ", "ok");

    const receipt = await publicClient!.waitForTransactionReceipt({ hash });
    let msg:string =  liqUsdc.value+" USDC has been approved!";
    if (receipt.status !== 'success')
        msg = "USDC approval failed!";
    showMessage (msg, receipt.status !== 'success'? "err" : "ok");
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
    const [intPart, fracPart = ""] = input.split(".");
    const frac = (fracPart + "000000").slice(0, 6);
    return BigInt(intPart) * 10n ** 6n + BigInt(frac);
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
  


async function main () : Promise <void> {
    if (!ensureEthereumOrWarn()) return; 
    const lpTokenAddress = await readContract ("getMyERC20ContractAddress",false, false, []) as `0x${string}`;
    console.log ("===>", lpTokenAddress);
    ensureEthereumOrWarn ();
    poolSeeded = await readContract ("isSeeded",false, false) as boolean;
    restoreConnection();
    initFetchFeed ();
    setProviderBtn ();
}

async function swapTokenInChanged ():Promise <void> {
    swapTokenOut.value = swapTokenIn.value === "USDC" ? "WETH" : "USDC";
    updateQuote ();
}

async function swapTokenOutChanged ():Promise <void> {
    swapTokenIn.value = swapTokenOut.value === "USDC" ? "WETH" : "USDC";
    updateQuote ();
}

async function updateQuote ():Promise <void> {
    const amount = (swapTokenIn.value === "USDC"? parseUsdc (swapAmountIn.value) : parseEther (swapAmountIn.value)) as bigint;
    quotedAmount = await getQuote (amount) as bigint;
    swapEstimatedOut.value = (swapTokenIn.value === "USDC"? formatEther (quotedAmount) : formatUsdc (quotedAmount)) as string ;
}
async function getQuote (amount:bigint):Promise <bigint> {
    return await readContract ("quoteOutAmount",false, true, [amount, swapTokenIn.value, swapTokenOut.value ]) as bigint;
}

async function swap () : Promise <void>  {
    const amount = (swapTokenIn.value === "USDC"? parseUsdc (swapAmountIn.value) : parseEther (swapAmountIn.value)) as bigint;
    if (amount <= 0) {
        showMessage (swapTokenIn.value+" amount too low!", "wrn");
        return;
    }
    const slippageStr = swapSlippage.value;
    const slippage = parseFloat (slippageStr); 
    if (isNaN(slippage)){
        showMessage ("wrong slippage percentage", "wrn");
        return;
    }
    if (slippage > 10) {
        showMessage ("slippage must be less than 10%","wrn");
        return;
    }
    const slippageBps = BigInt(Math.floor(slippage * 100)); 

    updateQuote ();
    const approveHash = swapTokenIn.value === "USDC" 
                ? await approveToken(USDC_CONTRACT_ADDRESS, amount)
                : await approveToken(WETH_CONTRACT_ADDRESS, amount);
    await publicClient!.waitForTransactionReceipt({ hash: approveHash });
    const hash = await writeContract ("swap", [amount, quotedAmount, slippageBps, swapTokenIn.value, swapTokenOut.value]);
    const receipt = await publicClient!.waitForTransactionReceipt({ hash });
    const quotedAmountStr = (swapTokenIn.value === "USDC"? formatEther (quotedAmount) : formatUsdc (quotedAmount)) as string ;
    if (receipt.status !== 'success')
        showMessage ("Swap Failed!","err");
    let msg:string = swapAmountIn.value +" "+ swapTokenIn.value+" has been swapped for "+ quotedAmountStr +" "+ swapTokenOut.value+"\n"+hash;
    showMessage (msg, "ok");
    initFetchFeed ();
} 

async function claimFees (): Promise <void> {
    const u = parseUsdc(feeUsdc.value) as bigint;
    const e = parseEther(feeEth.value) as bigint;
    if (u <=0 && e <= 0){
        showMessage ("Fees to withdraw is too low!", "wrn");
        return;
    }
    const hash = await writeContract ("withdrawProtocolReawrd", [u, e]);
    const receipt = await publicClient!.waitForTransactionReceipt({ hash });
    if (receipt.status !== 'success'){
        showMessage ("Withdrawal failed!", "err");
        return;
    }
    let suffix:string = u>0 ? feeUsdc.value + " USDC":"";
    suffix += e>0 ? " and "+feeEth.value + " ETH": ""; 
    const msg = "Withdrawn "+suffix+" to your wallet!" as string;
    showMessage (msg, "ok");
    refreshProviderFees ();
}

async function withdrawLiquidity (): Promise <void> {
    hideLiqStatus ();
    const uelp = parseUsdc(wdUelp.value) as bigint;
    if (uelp <=0){
        showMessage ("Withdrawal amount is too low!", "wrn");
        return;
    }
    const lpTokenAddress = await readContract ("getMyERC20ContractAddress",false, false, []) as `0x${string}`;
    const approveHash = await approveToken(lpTokenAddress, uelp);

    await publicClient!.waitForTransactionReceipt({ hash: approveHash });
    
    const hash = await writeContract ("withdrawLiquidity", [uelp]);
    const receipt = await publicClient!.waitForTransactionReceipt({ hash });
    if (receipt.status !== 'success') {
        showMessage ("Withdrawal failed!", "err");
        return;
    }
    showMessage("Withdrawal successful!", "ok");
}

async function refreshFees () : Promise <void> {
    refreshProviderFees ();
}

function showMessage(message: string, type: "ok" | "err" | "wrn") {
    status.textContent = message;
    status.classList.remove("hidden");
    status.classList.add(type);
}

function hideLiqStatus() {
    status.classList.add("hidden");
}

function calculateOtherAmount (amount:bigint, token:number): bigint | undefined {
    if (token<0 || token >1 ) {
        showMessage ("invalid token", "wrn");
        return;
    }
    let rate:number = parseFloat (kpiPrice.innerText);
    if (isNaN (rate)){
        showMessage ("Exchange Rate is not available", "wrn");
        return;
    }
    rate = rate + 10;
    if (token === 0) {
        const eth = Number(amount) / 1e18;
        const usdc = eth * rate;
        return BigInt(Math.floor(usdc * 1e6)); 
    } else {
        const usdc = Number(amount) / 1e6;
        const eth = usdc / rate;
        return BigInt(Math.floor(eth * 1e18)); 
    }
}

function updateLiqUSDC  () {
    if (!poolSeeded) return;
    const ethAmount = parseEther (liqEth.value) as bigint;
    if (ethAmount <=0){
        return;
    }
    const usdcAmount = calculateOtherAmount (ethAmount, 0);
    if (!usdcAmount)
        return;
    liqUsdc.value = formatUsdc (usdcAmount);
}

function updateLiqETH () {
    if (!poolSeeded) return;
    const usdcAmount = parseUsdc (liqUsdc.value) as bigint;
    if (usdcAmount <=0){
        return;
    }
    const ethAmount = calculateOtherAmount (usdcAmount, 1);
    if (!ethAmount)
        return;
    liqEth.value = formatEther (ethAmount);
}


btnConnect.onclick = connect
btnApproveEth.onclick = approveETH 
btnApproveUsdc.onclick = approveUSDC
btnProvide.onclick = provideLiquidity
swapTokenIn.onchange = swapTokenInChanged;
swapTokenOut.onchange = swapTokenOutChanged;
btnQuote.onclick = updateQuote
btnSwap.onclick = swap
btnClaimFees.onclick = claimFees
btnWithdraw.onclick = withdrawLiquidity 
btnRefreshFees.onclick = refreshFees
liqUsdc.onblur = updateLiqETH 
liqEth.onblur = updateLiqUSDC


main ();


/** -------- MetaMask install warning (platform-aware) -------- */
function detectPlatform(): "android" | "ios" | "desktop" {
    const ua = navigator.userAgent || navigator.vendor || "";
    const isAndroid = /Android/i.test(ua);
    const isIOS =
      /iPad|iPhone|iPod/i.test(ua) ||
      ((/Macintosh/i.test(ua) || /Mac OS X/i.test(ua)) && "ontouchend" in document);
  
    if (isAndroid) return "android";
    if (isIOS) return "ios";
    return "desktop";
  }
  

  
  
  function ensureEthereumOrWarn(): boolean {
    const hasEth = typeof (window as any).ethereum !== "undefined";
    if (hasEth)
      return true;
    
  
    const platform = detectPlatform();
    const METAMASK_LINK: Record<"android" | "ios" | "desktop", string> = {
        android: "https://play.google.com/store/apps/details?id=io.metamask",
        ios: "https://apps.apple.com/app/metamask-blockchain-wallet/id1438144202",
        desktop: "https://metamask.io/download/",
      };
    const targetUrl = METAMASK_LINK[platform];
    const label = platform === "desktop" ? "Desktop" : platform.toUpperCase();
    status.classList.remove ("hidden");
    status.innerHTML =
      `<div style="color:red">No Ethereum provider detected. ` +
      `Please <a href="${targetUrl}" target="_blank" rel="noopener">install MetaMask for ${label}</a> ` +
      `and then reload this page.</div>`;
  
    return false;
  }
  
