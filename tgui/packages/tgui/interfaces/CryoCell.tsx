import { BooleanLike } from 'common/react';
import { useBackend } from '../backend';
import {
  Button,
  LabeledList,
  Section,
  ProgressBar,
  AnimatedNumber,
} from '../components';
import { Window } from '../layouts';

type Occupant = {
  name: string;
  stat: number;
  health: number;
  maxHealth: number;
  bruteLoss: number;
  oxyLoss: number;
  toxLoss: number;
  fireLoss: number;
  bodyTemperature: number;
};

type CryoData = {
  isOperating: BooleanLike;
  hasOccupant: BooleanLike;
  beakerLoaded: BooleanLike;
  beakerLabel: string;
  cellTempStats: string;
  cellTemp: number;
  beakerVolume: number;
  currentStasis: number;
  slowStasis: number;
  fastStasis: number;
  occupant: Occupant;
};

const damageType = [
  {
    label: 'Увечья',
    type: 'bruteLoss',
  },
  {
    label: 'Ожоги',
    type: 'fireLoss',
  },
  {
    label: 'Кислород',
    type: 'oxyLoss',
  },
  {
    label: 'Токсины',
    type: 'toxLoss',
  },
] as const;

const statNames = [
  ['good', 'В сознании'],
  ['average', 'Без сознания'],
  ['bad', 'ТРУП'],
];

export const CryoCell = (props, context) => {
  const { act, data } = useBackend<CryoData>(context);
  const { isOperating, occupant } = data;
  return (
    <Window width={410} height={520}>
      <Window.Content>
        <Section
          title="Состояние"
          buttons={<Button icon="eject" onClick={() => act('ejectOccupant')} />}
        >
          <LabeledList>
            <LabeledList.Item label="Пациент">{occupant.name}</LabeledList.Item>
            <LabeledList.Item label="Здоровье">
              <ProgressBar
                min={occupant.health}
                max={occupant.maxHealth}
                value={occupant.health / occupant.maxHealth}
                color={occupant.health > 0 ? 'good' : 'average'}
              >
                <AnimatedNumber value={Math.round(occupant.health)} />
              </ProgressBar>
            </LabeledList.Item>
            <LabeledList.Item
              label="Состояние"
              color={statNames[occupant.stat][0]}
            >
              {statNames[occupant.stat][1]}
            </LabeledList.Item>
            <LabeledList.Item label="Температура тела" color>
              <AnimatedNumber
                value={Math.round(occupant.bodyTemperature - 273.15)}
              />
              {' C'}
            </LabeledList.Item>
            <LabeledList.Divider />
            {damageType.map((damageType) => (
              <LabeledList.Item key={damageType.type} label={damageType.label}>
                <ProgressBar
                  value={data.occupant[damageType.type] / 100}
                  ranges={{
                    average: [0.01, 0.33],
                    bad: [0.33, Infinity],
                  }}
                >
                  <AnimatedNumber value={data.occupant[damageType.type]} />
                </ProgressBar>
              </LabeledList.Item>
            ))}
          </LabeledList>
        </Section>
      </Window.Content>
    </Window>
  );
};
