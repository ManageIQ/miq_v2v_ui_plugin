import Immutable from 'seamless-immutable';

import overviewReducer from '../OverviewReducer';
import { FETCH_V2V_MIGRATIONS_IN_PROGRESS } from '../OverviewConstants';

import { activeServiceRequests } from '../overview.migrationsInProgress.fixtures';

const initialState = Immutable({
  mappingWizardVisible: false,
  hideMappingWizard: true,
  planWizardVisible: false,
  hidePlanWizard: true,
  planWizardId: null,
  transformationMappings: [],
  isRejectedTransformationMappings: false,
  isFetchingTransformationMappings: false,
  isContinuingToPlan: false,
  shouldReloadMappings: false,
  migrationsInProgress: [],
  isFetchingMigrationsInProgress: false,
  isRejectedMigrationsInProgress: false,
  errorMigrationsInProgress: null
});

test('sets default state', () => {
  const action = { type: '@@INIT' };
  const state = overviewReducer(undefined, action);

  expect(state).toEqual(initialState);
});

describe('fetching migrations in progress', () => {
  test('is pending', () => {
    const action = {
      type: `${FETCH_V2V_MIGRATIONS_IN_PROGRESS}_PENDING`
    };
    const state = overviewReducer(initialState, action);

    expect(state).toEqual({
      ...initialState,
      isFetchingMigrationsInProgress: true
    });
  });

  test('is rejected', () => {
    const action = {
      type: `${FETCH_V2V_MIGRATIONS_IN_PROGRESS}_REJECTED`,
      payload: 'error'
    };
    const prevState = initialState.set('isFetchingMigrationsInProgress', true);
    const state = overviewReducer(prevState, action);

    expect(state).toEqual({
      ...initialState,
      errorMigrationsInProgress: 'error',
      isRejectedMigrationsInProgress: true
    });
  });

  test('is fulfilled', () => {
    const payload = {
      data: activeServiceRequests
    };
    const action = {
      type: `${FETCH_V2V_MIGRATIONS_IN_PROGRESS}_FULFILLED`,
      payload
    };
    const prevState = initialState
      .set('isFetchingMigrationsInProgress', true)
      .set('isRejectedMigrationsInProgress', true)
      .set('errorMigrationsInProgress', 'error');
    const state = overviewReducer(prevState, action);

    expect(state).toEqual({
      ...initialState,
      migrationsInProgress: payload.data.resources
    });
  });
});
