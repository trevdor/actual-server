# Build an unreleased @actual-app/web from github
FROM node:16-bullseye as client
RUN apt-get update && apt-get install -y openssl git rsync

# Branch info to use for the @actual-app/web build
ENV USER=trevdor
ENV REPO=actual
ENV BRANCH=responsive

WORKDIR /actual
# cache invalidation. This should return a new value if the commit changes,
# forcing a rebuild from this step.
# ADD https://api.github.com/repos/$USER/$REPO/git/refs/heads/$BRANCH cache_version
# RUN rm cache_version && \
RUN git clone -b $BRANCH https://github.com/$USER/$REPO.git .
# CI true skips an unnecessary lint step
ENV CI=true
RUN yarn install
RUN ./bin/package-browser

# build the server with the FE from the previous step
FROM node:16-bullseye as base
RUN apt-get update && apt-get install -y openssl git rsync
WORKDIR /app
ENV NODE_ENV=production
RUN npm rebuild bcrypt --build-from-source
COPY yarn.lock package.json ./
RUN yarn install --production
COPY --from=client /actual/packages/desktop-client/build /app/node_modules/@actual-app/web/build

# final server build without any extras
FROM node:16-bullseye-slim as prod
RUN apt-get update && apt-get install -y openssl tini && apt-get clean -y && rm -rf /var/lib/apt/lists/
WORKDIR /app
COPY --from=base /app /app
COPY . .
ENTRYPOINT ["/usr/bin/tini","-g",  "--"]
CMD ["node", "app.js"]