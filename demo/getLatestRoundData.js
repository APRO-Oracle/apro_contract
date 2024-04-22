const { ethers, JsonRpcProvider } = require('ethers');
const fs = require("fs")
let rpc_url = "https://testnet-rpc.bitlayer.org";

// npx hardhat run demo/getLatestRoundData.js --network bitlayer
async function main() {
    const aggregator_proxy_address = "0xF8F8B81bC86EF4ffc9a46E7d952E65B8eeb7A8e9";
    const abi = JSON.parse(fs.readFileSync("./demo/abi/AggregatorV3Interface.json"));
    const provider = new JsonRpcProvider(rpc_url)
    const proxyContract = new ethers.Contract(aggregator_proxy_address, abi, provider);
    await proxyContract.latestRoundData().then(([roundId, answer, startedAt, updatedAt, answeredInRound]) => {
        console.log("answer", answer)
    });

    await proxyContract.decimals().then((decimals) => {
        console.log("decimals", decimals)
    });

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
    });
