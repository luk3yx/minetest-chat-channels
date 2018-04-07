# chat_channels

A client-side mod for Minetest that adds chat channels, inspired by
  [beerchat](https://github.com/evrooije/beerchat).

## Chat channels

Channels are sent via PMs to users.
Anyone can add you to a channel without your permission, and channels are not
  synced between users.
Chat channels are created automatically when adding the first user and deleted
  when removing the last user.

The following channel prefixes exist:

 - `@`: A PM. This will PM the user after the `@`.
 - `#`: A channel. This is just a group PM prefixed with the channel name. If
   a user in the channel uses chat_channels and has you in a channel with the
   same name, the message will display as a chat message in the channel.
   Otherwise, it will display as a PM prefixed in `-#channel-`.

## Added commands

 - `.add_to_channel <victim> [channel]`: Adds `<victim>` to the channel. If
   `[channel]` is not specified, the current channel will be used instead.
 - `.delete_channel <channel>`: Deletes a channel.
 - `.list_channels`: Displays a list of channels.
 - `.toggle_main`: Toggles between showing and hiding messages from #main.
 - `.remove_from_channel <victim> [channel]`: The same as `.add_to_channel`,
   except removes users instead.
 - `.who [channel]`: Displays a list of users in the channel. If `[channel]` is
   not specified, the current channel will be used.
