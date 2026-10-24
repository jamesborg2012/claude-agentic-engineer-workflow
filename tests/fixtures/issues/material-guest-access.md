# #103 Let readers save favourite articles

- **URL:** https://github.com/acme/web/issues/103
- **State:** OPEN
- **Author:** @octo
- **Labels:** none
- **Milestone:** none
- **Assignees:** none

## Body

### Summary

Readers want to keep articles to read later. Add a heart button to each article card on the home page that saves or unsaves the article, and a `/favourites` page that lists the saved articles. Favourites should still be there when readers come back.

### Behaviour

- The heart toggles between a filled and an outline state. Its accessible name is "Save article" when the article is not saved and "Remove from favourites" when it is.
- `/favourites` lists the saved articles in the order they were saved, newest first.
- With none saved, `/favourites` shows "You haven't saved any articles yet."

### Acceptance criteria

1. Selecting the heart on an article card saves the article, and selecting it again removes it.
2. The heart shows a filled state when the article is saved and an outline state when it is not.
3. The heart's accessible name is "Save article" or "Remove from favourites", matching its state.
4. `/favourites` lists the saved articles, newest first, and shows "You haven't saved any articles yet." when there are none.

## Comments (0)

None.

## Linked issues

- Parent: none
- Blocked by: none
- Blocking: none
- Sub-issues: none
- Closed by pull requests: none

## Referenced issues

none
