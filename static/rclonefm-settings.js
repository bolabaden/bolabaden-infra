
export const guiVersion = "0.4.0";
export const rcloneSettings = {
    host: "https://rclonefm.${DOMAIN}",
    // null if --rc-no-auth, otherwise what is set in --rc-user
    user: ${RCLONE_USER:-null},
    // null if --rc-no-auth, otherwise what is set in --rc-pass
    pass: ${RCLONE_PASS:-null},
    // null if there is no login_token in URL query parameters,
    // otherwise is set from there and takes over user/pass
    loginToken: ${RCLONE_LOGIN_TOKEN:-null}
};
export const asyncOperations = [
    "/sync/copy",
    "/sync/move",
    "/operations/purge",
    "/operations/copyfile",
    "/operations/movefile",
    "/operations/deletefile"
];
export const remotes = {
    "storage": {
        "startingFolder": "/mnt/remote",
        "canQueryDisk": true,
        "pathToQueryDisk": ""
    }
};
export const userSettings = {
    timerRefreshEnabled: true,
    timerRefreshView: 2,
    timerRefreshViewInterval: undefined,
    timerProcessQueue: 5,
    timerProcessQueueInterval: undefined
};
