Documents reflecting the continuous improvement process of the application.

Improvement types:
- architecture

General process:
- create a folder for the current improvement round `<round-number>-<improvement-type>`
- perform a review of a requested type, if type is not specified ask user, if type is not defined say to user and stop
Prompt:
```
You are a solution architect for mobile application including flutter and dart.
Review this codebase and analyze the current architecture (do not touch tests so far) from the code maintainability perspective and ease of future development and changes.
Report all your findings in an md file with the following sections: What was done good and bad. Split bad findings into severity categories (critical, middle, low).
For first 3 critical issues include the information that would allow to see the problem (diagrams, folder structures, existing code snippets, facts, decisions, and what you think make sense to add). This should allow another agent to validate issues and pick some for implementation.
Store the review in `S1-<improvement-type>-review.md` file.
```
- Analyze first three critical issues (or less if their number is smaller) and perform a deep analysis
Prompt:
```
Read the first three points for critical issues from this file `S1-<improvement-type>-review.md`.

Perform a deep analysis for each of them separately.
Make a conclusion if it is valid, the reasoning is correct, the proposed solution make sense.
Write the outcome in three separate files next to review.
For those you agree with store the issue with no or minimal (in case something important was missed) changes.
For those you disagree - store the explanation of the flaws of the proposed solution, work out your solution and append to the file.
File names must follow this pattern `S02-issue-<issue-number>.md`.
Think of the implementation sequence and if it is possible to implement them in parallel. Write proposed sequence to `S02-issues-impementation-sequence.md`
```

Folder structure
./R<round-number>-<improvement-type>/
   S1-<improvement-type>-review.md
   S2-issue-<issue-number>


TODO:
- branch name
- pr name
- create pr (gh), summary as description
- Use gh CLI to perform a code review of the PR#13 in handy-speak repo.
Read the description and check against it.


