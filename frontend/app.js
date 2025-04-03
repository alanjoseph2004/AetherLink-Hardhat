window.onload = async () => {
    if (typeof ethers === 'undefined') {
        console.error('Ethers.js library is not loaded.');
    } else {
        console.log('Ethers.js is loaded successfully.');
    }

    const connectButton = document.getElementById("connectWallet");
    const walletAddressElement = document.getElementById("walletAddress");
    const registerForm = document.getElementById("registerProductForm");
    const productTableBody = document.getElementById("productTableBody");

    let provider;
    let signer;
    let contract;

    // Smart contract details (Replace with your deployed contract details)
    const contractAddress = "0xYourContractAddress"; // Replace with your actual contract address
    const contractABI = [
        // Add your smart contract's ABI here
    ];

    // Connect Wallet Function
    async function connectWallet() {
        if (typeof window.ethereum === 'undefined') {
            alert('MetaMask not installed! Please install MetaMask.');
            return;
        }

        try {
            provider = new ethers.providers.Web3Provider(window.ethereum);
            await provider.send("eth_requestAccounts", []);
            signer = provider.getSigner();
            const address = await signer.getAddress();

            walletAddressElement.textContent = `Connected: ${address.slice(0,6)}...${address.slice(-4)}`;
            console.log("Wallet connected:", address);

            contract = new ethers.Contract(contractAddress, contractABI, signer);
        } catch (error) {
            console.error("Wallet connection failed", error);
        }
    }

    // Register Product Function
    async function registerProduct(event) {
        event.preventDefault();

        if (!contract) {
            alert("Connect wallet first!");
            return;
        }

        const name = document.getElementById("productName").value;
        const details = document.getElementById("productDetails").value;
        const quantity = document.getElementById("productQuantity").value;
        const price = document.getElementById("productPrice").value;

        try {
            const tx = await contract.registerProduct(name, details, quantity, ethers.utils.parseEther(price));
            await tx.wait();

            alert("Product registered successfully!");
            registerForm.reset();
            loadProducts();
        } catch (error) {
            console.error("Error registering product:", error);
        }
    }

    // Load Products Function
    async function loadProducts() {
        if (!contract) return;

        try {
            const productCount = await contract.getProductCount();
            productTableBody.innerHTML = "";

            for (let i = 0; i < productCount; i++) {
                const product = await contract.getProduct(i);
                const row = `<tr>
                    <td>${i}</td>
                    <td>${product.name}</td>
                    <td>${product.quantity}</td>
                    <td>${ethers.utils.formatEther(product.price)} ETH</td>
                    <td>${product.status}</td>
                    <td><button onclick="updateProduct(${i})">Update</button></td>
                </tr>`;
                productTableBody.innerHTML += row;
            }
        } catch (error) {
            console.error("Error loading products:", error);
        }
    }

    // Attach Event Listeners
    connectButton.addEventListener("click", connectWallet);
    registerForm.addEventListener("submit", registerProduct);
};
