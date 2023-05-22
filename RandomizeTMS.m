function PostRandomTable = RandomizeTMS(ProtocolTable)

% Determining the number of steps in each grouping and which groupings are
% randomized

% Starting group number
GroupingID = ProtocolTable(1,1);

% Counters
GroupingCounter = 0;
j = 1;
RandomVariable = 0;
Random = table({'Block'},{'Random'});

% Counter number of groupings total and which ones are random 
for i = 1:height(ProtocolTable)
    if isequal(ProtocolTable(i,1),GroupingID)
        GroupingCounter = GroupingCounter + 1;
        if isequal(ProtocolTable(i,2),Random(1,2))
            RandomVariable = 1; %Random
        end
    else
        GroupingAmounts(j) = GroupingCounter;
        RandomorBlock(j) = RandomVariable;
        GroupingCounter = 1;
        j = j + 1;
        GroupingID = ProtocolTable(i,1);
        RandomVariable = 0;
    end
end

GroupingAmounts(j) = GroupingCounter;
RandomorBlock(j) = RandomVariable;

% Randomizing the groupings that are random
a = 1;

for i = 1:length(RandomorBlock)
    b = a + GroupingAmounts(i) - 1;
    Order = linspace(1,GroupingAmounts(i),GroupingAmounts(i));
    if RandomorBlock(i) == 1
        X = randperm(numel(Order));
        Order = reshape(Order(X),size(Order));
    end
    PreRandomTable = ProtocolTable(a:b,:);
    for j = 1:height(PreRandomTable)
        RandomPosition = Order(j);
        PostRandomTable(j+a-1,:) = PreRandomTable(RandomPosition,:);
    end
    a = a + GroupingAmounts(i);
end

end