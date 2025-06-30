function PostRandomTable = RandomizeTMS(ProtocolTable)

% Determining the number of steps in each grouping and which groupings are
% randomized

% Starting group number
GroupingID = ProtocolTable(1,1);

% Initializing counters
GroupingCounter = 0;
j = 1;
RandomVariable = 0;
Random = table({'Block'},{'Random'});

% Count number of groupings total and which ones are random 
for i = 1:height(ProtocolTable)
    if isequal(ProtocolTable(i,1),GroupingID) % Checks group number 
        GroupingCounter = GroupingCounter + 1; % Number of blocks in each group
        if isequal(ProtocolTable(i,2),Random(1,2)) % If grouping is random
            RandomVariable = 1; % Random
        end
    elseif i == height(ProtocolTable)
        if isequal(ProtocolTable(i,2),Random(1,2)) % If grouping is random
            RandomVariable = 1; % Random
        end
        GroupingAmounts(j) = GroupingCounter; % Table of number of blocks in each group
        RandomorBlock(j) = RandomVariable; % Table of whether each group is random or blocked
        % Counters
        GroupingCounter = 1;
        j = j + 1;
        GroupingID = ProtocolTable(i,1);
        RandomVariable = 0;
    else
        GroupingAmounts(j) = GroupingCounter; % Table of number of blocks in each group
        RandomorBlock(j) = RandomVariable; % Table of whether each group is random or blocked
        % Counters
        GroupingCounter = 1;
        j = j + 1;
        GroupingID = ProtocolTable(i,1);
        RandomVariable = 0;
    end
end

for i = 1:height(ProtocolTable)
    TrialNumber(:,i) = ProtocolTable(i,6); % Makes a table with all numbers of trials
end

GroupingAmounts(j) = GroupingCounter; % Table of number of blocks in each group
RandomorBlock(j) = RandomVariable; % Table of whether each group is random or blocked
TrialNumber(:,i) = ProtocolTable(i,6); % Makes a table with all numbers of trials
TrialNumber = table2array(TrialNumber);

% Seperating each pulse in randomized trials
RowCounter = 0; % Initialize counter
for i = 1:length(TrialNumber)
    if isequal(ProtocolTable(i,2),Random(1,2)) % If grouping is random
        RowAddition = TrialNumber(i);
        for j = 1:TrialNumber(i)
            TempTable(j+RowCounter,:) = ProtocolTable(i,:); % Seperate random grouping rows
            TempTable(j+RowCounter,6) = num2cell(1); % Change each pulse counter to 1
        end
    else % If grouping is blocked
        TempTable(RowCounter+1,:) = ProtocolTable(i,:); % Copy blocked grouping rows
        RowAddition = 1;
    end
    RowCounter = RowCounter + RowAddition; % Updates number of current rows
end

% Randomizing random groupings
a = 0; % Counter
PreRandomTable = TempTable; % Starting table with extended rows

for i = 1:length(RandomorBlock)
    Trials = 0;
    if RandomorBlock(i) == 1
        for k = 1:GroupingAmounts(i)
            Trials = Trials + TrialNumber(k); % Row Number to be Randomized
        end
    else
        Trials = GroupingAmounts(i);
    end
    Order = linspace(1,Trials,Trials); % Non-randomized order
    if RandomorBlock(i) == 1
        X = randperm(numel(Order)); % Create a random order
        Order = reshape(Order(X),size(Order)); % Apply this random order to preset order
    end
    for j = 1:Trials
        RandomPosition = Order(j);
        PostRandomTable(j+a,:) = PreRandomTable(RandomPosition+a,:); % Put trials into position, either random or not
    end
    a = a + Trials; % Row counter
end

end