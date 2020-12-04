import Vue from "vue";
import Vuex from "vuex";
import VueRouter from "vue-router";
import { createLocalVue, mount } from "@vue/test-utils";
import { SpiStore } from "@/store/store";
import Home from "@/views/Home.vue";
import Model from "@/views/Model.vue";
import App from "@/App.vue";
import { domain, clientId, audience } from "../../auth_config.json";

const user = {
  email: "testing@solaforecastarbiter.org",
  email_verified: true,
  sub: "auth0|5fa9596ccf64f9006e841a3a"
};

const localVue = createLocalVue();

const $auth = {
  isAuthenticated: true,
  loading: false,
  user: user,
  logout: jest.fn(),
  loginWithRedirect: jest.fn()
};

function resetAuthMocks() {
  $auth.logout.mockClear();
  $auth.loginWithRedirect.mockClear();
}

localVue.use(Vuex);
localVue.use(VueRouter);

describe("Tests authenticated routes", () => {
  let actions: any;
  let store: any;
  let state: any;
  beforeEach(() => {
    actions = {
      fetchSystems: jest.fn()
    };
    state = {
      systems: []
    };
    store = new Vuex.Store({
      state,
      actions
    });
    $auth.isAuthenticated = false;
    jest.clearAllMocks();
  });
  it("unauthenticated home", async () => {
    const home = mount(Home, {
      store,
      localVue,
      mocks: {
        $auth
      }
    });
    expect(home.find("p").text()).toMatch(/Welcome to the solar/);
    const button = home.find("button");
    expect(button.text()).toMatch(/Log in/);
    expect($auth.loginWithRedirect).not.toHaveBeenCalled();
    await button.trigger("click");
    expect($auth.loginWithRedirect).toHaveBeenCalled();
    expect($auth.logout).not.toHaveBeenCalled();
    expect(actions.fetchSystems).not.toHaveBeenCalled();
  });
});

describe("Tests authenticated routes", () => {
  let actions: any;
  let store: any;
  let state: any;
  beforeEach(() => {
    actions = {
      fetchSystems: jest.fn()
    };
    state = {
      systems: []
    };
    store = new Vuex.Store({
      state,
      actions
    });
    $auth.isAuthenticated = true;
    jest.clearAllMocks();
  });
  it("authenticated home", async () => {
    const home = mount(Home, {
      store,
      localVue,
      mocks: {
        $auth
      }
    });
    expect(home.find("p").text()).toMatch(/Successfully logged in./);
    const button = home.find("button");
    expect(button.text()).toMatch(/Log out/);
    expect($auth.logout).not.toHaveBeenCalled();
    await button.trigger("click");
    expect($auth.logout).toHaveBeenCalled();
    expect($auth.loginWithRedirect).not.toHaveBeenCalled();
    expect(actions.fetchSystems).not.toHaveBeenCalled();
  });
});

import { authGuard } from "../../src/auth/authGuard";
import * as auth from "../../src/auth/auth";

const mockedAuthInstance = jest.spyOn(auth, "getInstance");
// @ts-expect-error
mockedAuthInstance.mockImplementation(() => $auth);
const routes = [
  {
    name: "home",
    path: "/",
    component: Home
  },
  {
    name: "systems",
    path: "/system",
    component: Model,
    beforeEnter: authGuard
  }
];
describe("Test authguard", () => {
  let actions: any;
  let store: any;
  let state: any;
  let router: any;
  beforeEach(() => {
    actions = {
      fetchSystems: jest.fn()
    };
    state = {
      systems: []
    };
    store = new Vuex.Store({
      state,
      actions
    });
    router = new VueRouter({
      mode: "history",
      base: process.env.BASE_URL,
      routes: routes
    });
    jest.clearAllMocks();
  });

  it("test unauthenticated access to protected route", async () => {
    $auth.isAuthenticated = false;
    const view = mount(App, {
      store,
      localVue,
      router,
      mocks: {
        $auth
      }
    });
    expect(view.find("p").text()).toMatch(/Welcome to the solar/);
    expect($auth.loginWithRedirect).not.toHaveBeenCalled();
    router.push({ name: "systems" });
    await Vue.nextTick();
    expect($auth.loginWithRedirect).toHaveBeenCalled();
    // assert view has not changed since loginWithRedirect is mocked and does
    // nothing
    expect(view.find("p").text()).toMatch(/Welcome to the solar/);
  });
  it("test authenticated access to protected route", async () => {
    $auth.isAuthenticated = true;
    const view = mount(App, {
      store,
      localVue,
      router,
      mocks: {
        $auth
      }
    });
    expect(view.find("p").text()).toMatch(/Successfully logged in/);
    expect($auth.loginWithRedirect).not.toHaveBeenCalled();
    router.push({ name: "systems" });
    await Vue.nextTick();
    expect($auth.loginWithRedirect).not.toHaveBeenCalled();
    // Assert view at new path is rendered
    expect(view.find("h1").text()).toMatch(/New System/);
  });
});