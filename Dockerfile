# Runs the Playwright tests. The image already includes Node and the browsers.
# Keep this tag in step with @playwright/test in package-lock.json.
FROM mcr.microsoft.com/playwright:v1.58.2-noble

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .

# Without this the HTML reporter starts a server on failure and the container hangs
ENV PLAYWRIGHT_HTML_OPEN=never
# Written under /output so a mounted host folder can receive the report
ENV PLAYWRIGHT_HTML_OUTPUT_DIR=/output/playwright-report

CMD ["npx", "playwright", "test"]
