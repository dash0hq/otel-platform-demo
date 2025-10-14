import express from "express";
import winston from "winston";

const { combine, timestamp, json } = winston.format;

const logger = winston.createLogger({
	format: combine(timestamp(), json()),
	transports: [new winston.transports.Console()],
});

const app = express();
const PORT = ${{ values.port }};

app.use(express.json());

const checkForBadWords = (todoName) => {
	logger.info("checking for bad words");

	const lowerName = todoName.toLowerCase();
	const hasBadWords =
		lowerName.includes("bad") ||
		lowerName.includes("terrible") ||
		lowerName.includes("awful");

	return hasBadWords;
};

app.post("/validate/todo-name", async (req, res) => {
	const { name } = req.body;

	if (!name || name.trim() === "") {
		return res
			.status(400)
			.json({ valid: false, message: "Todo name cannot be empty" });
	}

	if (checkForBadWords(name)) {
		return res.status(400).json({
			valid: false,
			message: "Todo name contains inappropriate content",
		});
	}

	return res.json({ valid: true, message: "Todo name is valid" });
});

app.get("/health", (_req, res) => {
	res.json({ status: "UP", service: "${{ values.serviceName }}" });
});

app.listen(PORT, () => {
	console.log(`${{ values.serviceName }} (Node.js) listening on port ${PORT}`);
});
